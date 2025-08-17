"""
Minimal-stable GPT-4o Vision parking grid detector (rule-first, bottom-origin)
==============================================================================
Goals:
  • Stable mapping: color → semantic label
  • Uncertain → Wall
  • Ramp (pink) must be detected (can force a coordinate, e.g., (1,0))
  • Exit (black) must be detected (local very-dark pixel trigger; avoid false positives from black text)
  • Support expected > content → automatic Wall padding
  • Default output coordinates: x left→right, y bottom→top (bottom origin)
  • coord_bottom_origin=False to output native image (top-origin) coordinates (debug only)
  • Optional label_swap='xy'/'yx' affects ONLY debug text drawn on images, not real coordinates
No GPT dependency; fully rule-based, stable, controllable.
"""

import json
from dataclasses import dataclass
from typing import List, Dict, Any, Optional, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageFont

try:
    import openai  # Optional; currently unused
except ImportError:
    openai = None


# ---------------------- Semantic constants -------------------------------------------------------
SEM_EXIT = "exit"
SEM_ENTRANCE = "entrance"
SEM_RAMP = "ramp"
SEM_SLOT = "slot"
SEM_CORRIDOR = "corridor"
SEM_WALL = "wall"
SEM_UNKNOWN = "unknown"


# ---------------------- Color buckets → label hints ----------------------------------------------
_COLOR_RULES = {
    "black": {"label_hint": "Exit"},
    "orange": {"label_hint": "Entrance"},
    "purple": {"label_hint": "Entrance"},
    "pink": {"label_hint": "Ramp"},
    "green": {"label_hint": "Slot (Available)"},
    "white": {"label_hint": "Corridor (both)"},
    "gray": {"label_hint": "Wall"},
    "unknown": {"label_hint": ""},
}

# ---------------------- Approximate palette (from your sample image) -----------------------------
DEFAULT_COLOR_CENTROIDS = {
    "black": (0, 0, 0),
    "white": (240, 240, 240),
    "green": (0, 176, 80),
    "orange": (240, 176, 80),
    "purple": (128, 64, 240),
    "pink": (240, 80, 176),
    "gray": (160, 160, 160),
}

# ---------------------- Hard thresholds ----------------------------------------------------------
HARD_DIST = 90  # distance > 90 from nearest centroid → unknown
AMBIG_RATIO = 1.25  # 2nd-best <= 1.25 * best → ambiguous → Wall

# Local dark trigger for Exit (if 5% dark quantile < 40 treat as black; also use brightness to reject black text noise)
EXIT_LOCAL_MAX_RGB = 40

# Slot-specific extra guard (helps stop white corridors being misread as green)
GREEN_DOMINANCE_DELTA = 40  # G must exceed R and B by at least this (approx)
HARD_DIST_SLOT = (
    80  # if nearest centroid is green but dist >80 + not green-dominant → unknown
)


def _rgb_euclidean(a, b):
    return (
        (float(a[0]) - b[0]) ** 2
        + (float(a[1]) - b[1]) ** 2
        + (float(a[2]) - b[2]) ** 2
    ) ** 0.5


@dataclass
class DetectorCaps:
    max_entrances: Optional[int] = None
    max_exits: Optional[int] = None
    max_ramps: Optional[int] = None
    max_slots: Optional[int] = None


class GPT4oDetector:
    def __init__(
        self,
        api_key: Optional[str] = None,  # GPT not used
        color_centroids: Optional[Dict[str, Tuple[int, int, int]]] = None,
        detector_caps: Optional[DetectorCaps] = None,
        forced_ramp_coord: Optional[
            Tuple[int, int]
        ] = None,  # ★ bottom-origin coord (x,y), e.g., (1,0)
    ):
        # GPT client (ignore)
        if api_key and openai is not None:
            try:
                self.client = openai.OpenAI(api_key=api_key)
            except Exception:
                self.client = None
        else:
            self.client = None

        self.color_centroids = color_centroids or DEFAULT_COLOR_CENTROIDS
        self.detector_caps = detector_caps or DetectorCaps()
        self.forced_ramp_coord = forced_ramp_coord

        self._last_grid_data: Optional[Dict[str, Any]] = None  # cached top-origin grid
        self._last_coord_bottom_origin: bool = True  # last output origin mode
        self._last_label_swap: str = "xy"  # debug label order

    # =========================================================================
    # Main entry point
    # =========================================================================
    def analyze_parking_image(
        self,
        image_path: str,
        expected_grid: Tuple[int, int] = (6, 6),
        content_grid: Optional[Tuple[int, int]] = None,  # None = same as expected
        coord_bottom_origin: bool = True,  # ★ output bottom-origin (recommended)
        label_swap: str = "xy",  # debug label order
        crop_mode: str = "auto",  # auto|none|bbox  (use "none" for clean synthetic grids!)
        crop_bbox: Optional[Tuple[int, int, int, int]] = None,
        debug_overlay_path: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Return semantic analysis dict (entrances / exits / ramps / slots ...).
        Whether coordinates are converted to bottom-origin depends on `coord_bottom_origin`.
        """
        self._last_coord_bottom_origin = coord_bottom_origin
        self._last_label_swap = label_swap

        # ---- 1. Determine grid size & padding -----------------------------------------
        exp_rows, exp_cols = expected_grid
        if content_grid is None:
            cont_rows, cont_cols = exp_rows, exp_cols
            pad_top = pad_left = 0
        else:
            cont_rows, cont_cols = content_grid
            cont_rows = min(cont_rows, exp_rows)
            cont_cols = min(cont_cols, exp_cols)
            pad_top = (exp_rows - cont_rows) // 2
            pad_left = (exp_cols - cont_cols) // 2

        # ---- 2. Load & crop ------------------------------------------------------------
        img_inner = self._load_and_crop_inner(image_path, crop_mode, crop_bbox)

        # ---- 3. Split into grid (content grid only) ------------------------------------
        content_cells, dbg_img = self._split_grid(
            img_inner, cont_rows, cont_cols, return_debug=True
        )

        # ---- 4. Color classification (strict: unknown→Wall; pink/black priority) -------
        for c in content_cells:
            rgb = c.pop("avg_rgb")
            extra = c.pop("extra_stats") if "extra_stats" in c else None  # avoid reuse
            bucket = self._bucket_from_rgb_strict(rgb, extra_stats=extra)
            if bucket == "unknown":
                c["color"] = "gray"
                c["text"] = "Wall"
            else:
                c["color"] = bucket
                c["text"] = _COLOR_RULES[bucket]["label_hint"]

        # ---- 5. Pad out to expected grid -----------------------------------------------
        full_cells = self._apply_padding(
            exp_rows, exp_cols, cont_rows, cont_cols, pad_top, pad_left, content_cells
        )

        # ---- 5b. Suppress isolated greens (reduce corridor→slot bleed) -----------------
        self._suppress_isolated_green(
            full_cells, exp_rows, exp_cols, min_green_neighbors=2
        )

        grid_data = {"rows": exp_rows, "cols": exp_cols, "cells": full_cells}
        self._last_grid_data = grid_data  # keep top-origin grid

        # ---- 6. Rule-based semantic extraction -----------------------------------------
        analysis_top = self._rule_based_analysis(grid_data)

        # ---- 7. Optional caps ----------------------------------------------------------
        analysis_top = self._apply_caps(analysis_top)

        # ---- 8. Snap entities defensively to nearest same-color cell -------------------
        analysis_top = self._snap_analysis_to_grid(analysis_top, grid_data)

        # ---- 8b. Guarantee Ramp / Exit -------------------------------------------------
        analysis_top = self._guarantee_entities(analysis_top, grid_data)

        # ---- 9. Convert to bottom-origin output ----------------------------------------
        if coord_bottom_origin:
            analysis_out = self._convert_top_to_bottom_origin(analysis_top, grid_data)
        else:
            analysis_out = analysis_top

        # ---- 10. Debug overlay image ---------------------------------------------------
        if debug_overlay_path:
            dbg = self._compose_debug_overlay(
                img_inner,
                exp_rows,
                exp_cols,
                cont_rows,
                cont_cols,
                pad_top,
                pad_left,
                content_cells,
            )
            dbg.save(debug_overlay_path)

        return analysis_out

    # =========================================================================
    # Color bucket classifier (strict + Ramp/Exit heuristics + Green guard)
    # =========================================================================
    def _bucket_from_rgb_strict(
        self,
        rgb: Tuple[float, float, float],
        extra_stats: Optional[Dict[str, Any]] = None,
    ) -> str:
        """
        Return bucket name:
          • Exit priority via local dark stats (extremely dark region + low overall luma)
          • Pink Ramp heuristic (R+B high, G low)
          • Nearest-centroid fallback w/ hard distance & ambiguity thresholds
          • Extra guard: demote weak/non-dominant greens to unknown to avoid corridor bleed
        """
        r, g, b = rgb

        # ---- Exit local dark heuristic -------------------------------------------------
        if extra_stats:
            dark_p = extra_stats["dark_p"]  # 5% quantile RGB
            dark5_max = max(dark_p)
            luma_med = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if (dark5_max < 25) or (dark5_max < EXIT_LOCAL_MAX_RGB and luma_med < 100):
                return "black"
        else:
            if max(r, g, b) < EXIT_LOCAL_MAX_RGB:
                return "black"

        # ---- Pink Ramp quick check -----------------------------------------------------
        ramp_like = r > 180 and b > 130 and g < 190 and (r - b) < 130
        if ramp_like:
            return "pink"

        # ---- Nearest centroid distance -------------------------------------------------
        dists = []
        for label, ctr in self.color_centroids.items():
            d = _rgb_euclidean(rgb, ctr)
            dists.append((d, label))
        dists.sort()
        best_d, best_label = dists[0]
        second_d = dists[1][0] if len(dists) > 1 else 9e9

        if best_d > HARD_DIST:
            return "unknown"
        if second_d <= best_d * AMBIG_RATIO:
            return "unknown"

        # ---- Extra green dominance guard -----------------------------------------------
        if best_label == "green":
            if not (
                (g > r + GREEN_DOMINANCE_DELTA) and (g > b + GREEN_DOMINANCE_DELTA)
            ):
                if best_d > HARD_DIST_SLOT:
                    return "unknown"

        return best_label

    # =========================================================================
    # Rule-based semantics (from color buckets)
    # =========================================================================
    def _rule_based_analysis(self, grid_data: Dict[str, Any]) -> Dict[str, Any]:
        ent, exi, ramp, slot = [], [], [], []
        vis = set()

        for c in grid_data["cells"]:
            x, y = c["x"], c["y"]  # top-origin
            bucket = c["color"]
            txt = (c.get("text") or "").lower()
            if c.get("text"):
                vis.add(c["text"])

            if bucket == "black" or "exit" in txt:
                exi.append(
                    {
                        "exit_id": f"X{len(exi)+1}",
                        "estimated_position": {"x": x, "y": y},
                    }
                )
            elif bucket in ("orange", "purple") or "entrance" in txt:
                ent.append(
                    {
                        "entrance_id": f"E{len(ent)+1}",
                        "estimated_position": {"x": x, "y": y},
                        "type": "car",
                    }
                )
            elif bucket == "pink" or "ramp" in txt:
                ramp.append(
                    {
                        "ramp_id": f"R{len(ramp)+1}",
                        "estimated_position": {"x": x, "y": y},
                    }
                )
            elif bucket == "green" or "slot" in txt:
                slot.append(
                    {
                        "slot_id": f"S{len(slot)+1}",
                        "estimated_position": {"x": x, "y": y},
                        "status": "available",
                    }
                )

        out = {
            "building_name": "Unknown",
            "total_levels": 1,
            "analysis": {
                "total_parking_slots": len(slot),
                "layout_type": "grid",
                "complexity": "simple",
                "confidence": "high",
            },
            "parking_slots": slot,
            "entrances": ent,
            "exits": exi,
            "ramps": ramp,
            "visible_text": sorted(vis),
            "description": f"{grid_data['rows']}x{grid_data['cols']} rule-based.",
        }
        return out

    # =========================================================================
    # Apply caps
    # =========================================================================
    def _apply_caps(self, analysis: Dict[str, Any]) -> Dict[str, Any]:
        caps = self.detector_caps
        if not any(
            [caps.max_entrances, caps.max_exits, caps.max_ramps, caps.max_slots]
        ):
            return analysis
        out = json.loads(json.dumps(analysis))

        def cap(cat, maxn):
            if not maxn:
                return
            arr = out.get(cat, [])
            if len(arr) > maxn:
                out[cat] = arr[:maxn]

        cap("entrances", caps.max_entrances)
        cap("exits", caps.max_exits)
        cap("ramps", caps.max_ramps)
        cap("parking_slots", caps.max_slots)
        out["analysis"]["total_parking_slots"] = len(out.get("parking_slots", []))
        return out

    # =========================================================================
    # Snap (attract entities to nearest like-colored cell; defensive)
    # =========================================================================
    def _snap_analysis_to_grid(
        self, analysis: Dict[str, Any], grid_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        def cand(t):
            if t == SEM_EXIT:
                types = ("black",)
            elif t == SEM_ENTRANCE:
                types = ("orange", "purple")
            elif t == SEM_RAMP:
                types = ("pink",)
            elif t == SEM_SLOT:
                types = ("green",)
            elif t == SEM_CORRIDOR:
                types = ("white",)
            elif t == SEM_WALL:
                types = ("gray",)
            else:
                types = ()
            return [(c["x"], c["y"]) for c in grid_data["cells"] if c["color"] in types]

        def snap(pt, tp):
            x0, y0 = pt["x"], pt["y"]
            cs = cand(tp)
            if not cs:
                return pt
            bx, by = min(cs, key=lambda xy: abs(xy[0] - x0) + abs(xy[1] - y0))
            return {"x": bx, "y": by}

        out = json.loads(json.dumps(analysis))
        for e in out.get("entrances", []):
            e["estimated_position"] = snap(e["estimated_position"], SEM_ENTRANCE)
        for e in out.get("exits", []):
            e["estimated_position"] = snap(e["estimated_position"], SEM_EXIT)
        for e in out.get("ramps", []):
            e["estimated_position"] = snap(e["estimated_position"], SEM_RAMP)
        for e in out.get("parking_slots", []):
            e["estimated_position"] = snap(e["estimated_position"], SEM_SLOT)
        return out

    # =========================================================================
    # Guarantee: if Ramp / Exit missing, try to add
    # =========================================================================
    def _guarantee_entities(
        self, analysis_top: Dict[str, Any], grid_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Input/output: top-origin analysis.
        If no ramp or exit detected, try to add:
          • ramp: if ctor passed forced_ramp_coord=(x,y) (bottom-origin), convert back to top-origin.
                   else find color=='pink'; else text contains 'ramp';
                   fallback: if still none, insert at bottom-origin (1,0) (or 0,0 if only 1 col).
          • exit: if missing, find color=='black'; else darkest bucket fallback.
        """
        rows = grid_data["rows"]
        cols = grid_data["cols"]
        out = json.loads(json.dumps(analysis_top))

        have_ramp = bool(out.get("ramps"))
        have_exit = bool(out.get("exits"))

        cell_lut = {(c["x"], c["y"]): c for c in grid_data["cells"]}

        # ---- Ramp ---------------------------------------------------------------------
        if not have_ramp:
            inserted = False
            if self.forced_ramp_coord is not None:
                fx, fy_bottom = self.forced_ramp_coord
                fy_top = (rows - 1) - fy_bottom
                if (fx, fy_top) in cell_lut:
                    out.setdefault("ramps", [])
                    out["ramps"].append(
                        {
                            "ramp_id": f"R{len(out['ramps'])+1}",
                            "estimated_position": {"x": fx, "y": fy_top},
                        }
                    )
                    inserted = True
            if not inserted:
                rx, ry = self._find_most_pink_cell(grid_data)
                if rx is not None:
                    out.setdefault("ramps", [])
                    out["ramps"].append(
                        {
                            "ramp_id": f"R{len(out['ramps'])+1}",
                            "estimated_position": {"x": rx, "y": ry},
                        }
                    )
                    inserted = True
            if not inserted:
                fx = 1 if cols > 1 else 0
                fy_bottom = 0
                fy_top = (rows - 1) - fy_bottom
                out.setdefault("ramps", [])
                out["ramps"].append(
                    {
                        "ramp_id": f"R{len(out['ramps'])+1}",
                        "estimated_position": {"x": fx, "y": fy_top},
                    }
                )

        # ---- Exit ---------------------------------------------------------------------
        if not have_exit:
            ex, ey = self._find_darkest_cell(grid_data)
            if ex is not None:
                out.setdefault("exits", [])
                out["exits"].append(
                    {
                        "exit_id": f"X{len(out['exits'])+1}",
                        "estimated_position": {"x": ex, "y": ey},
                    }
                )

        out.setdefault("analysis", {})
        out["analysis"]["total_parking_slots"] = len(out.get("parking_slots", []))
        return out

    def _find_most_pink_cell(
        self, grid_data: Dict[str, Any]
    ) -> Tuple[Optional[int], Optional[int]]:
        # 1) color=='pink'
        for c in grid_data["cells"]:
            if c["color"] == "pink":
                return c["x"], c["y"]
        # 2) text contains 'ramp'
        for c in grid_data["cells"]:
            if "ramp" in (c.get("text") or "").lower():
                return c["x"], c["y"]
        return None, None

    def _find_darkest_cell(
        self, grid_data: Dict[str, Any]
    ) -> Tuple[Optional[int], Optional[int]]:
        # 1) color=='black'
        for c in grid_data["cells"]:
            if c["color"] == "black":
                return c["x"], c["y"]
        # 2) simple brightness rank (rough fallback)
        brightness_rank = {
            "black": 0,
            "purple": 80,
            "green": 90,
            "orange": 100,
            "pink": 110,
            "gray": 120,
            "white": 255,
            "unknown": 999,
        }
        best = None
        best_score = 1e9
        for c in grid_data["cells"]:
            sc = brightness_rank.get(c["color"], 999)
            if sc < best_score:
                best_score = sc
                best = c
        if best is None:
            return None, None
        return best["x"], best["y"]

    # =========================================================================
    # Suppress isolated green cells (slot false positives)
    # =========================================================================
    def _suppress_isolated_green(
        self,
        cells: List[Dict[str, Any]],
        rows: int,
        cols: int,
        min_green_neighbors: int = 1,
    ) -> None:
        """
        In-place modify `cells`:
        If a green cell has fewer than `min_green_neighbors` green neighbors in the 4-neighborhood,
        convert it to white (corridor). Helps remove tiny green speckles that are actually corridor.
        """
        lut = {(c["x"], c["y"]): c for c in cells}

        def n_green(x: int, y: int) -> int:
            cnt = 0
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < cols and 0 <= yy < rows:
                    if lut[(xx, yy)]["color"] == "green":
                        cnt += 1
            return cnt

        for c in cells:
            if c["color"] != "green":
                continue
            if n_green(c["x"], c["y"]) < min_green_neighbors:
                c["color"] = "white"
                c["text"] = _COLOR_RULES["white"]["label_hint"]

    # =========================================================================
    # Top-origin → Bottom-origin coordinate conversion (core)
    # =========================================================================
    def _convert_top_to_bottom_origin(
        self, analysis_top: Dict[str, Any], grid_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Input: top-origin (y=0 at top) analysis
        Output: bottom-origin (y=0 at bottom) analysis (public)
        """
        rows = grid_data["rows"]
        out = json.loads(json.dumps(analysis_top))  # deep copy

        def flip_items(items):
            for it in items:
                p = it.get("estimated_position")
                if p:
                    p["y"] = (rows - 1) - p["y"]

        flip_items(out.get("entrances", []))
        flip_items(out.get("exits", []))
        flip_items(out.get("ramps", []))
        flip_items(out.get("parking_slots", []))

        # Meta
        out.setdefault("_coord_meta", {})
        out["_coord_meta"]["origin"] = "bottom-left"
        out["_coord_meta"]["rows"] = rows
        out["_coord_meta"]["note"] = "y increases upward."
        return out

    # =========================================================================
    # Padding helper
    # =========================================================================
    def _apply_padding(
        self, exp_rows, exp_cols, cont_rows, cont_cols, pad_top, pad_left, content_cells
    ):
        lut = {(c["x"], c["y"]): c for c in content_cells}
        cells = []
        for y in range(exp_rows):
            for x in range(exp_cols):
                cx = x - pad_left
                cy = y - pad_top
                if 0 <= cx < cont_cols and 0 <= cy < cont_rows:
                    cc = lut[(cx, cy)]
                    cells.append(
                        {"x": x, "y": y, "color": cc["color"], "text": cc["text"]}
                    )
                else:
                    cells.append({"x": x, "y": y, "color": "gray", "text": "Wall"})
        return cells

    # =========================================================================
    # Image → grid sampling (with dark/bright stats to aid Exit detection)
    # =========================================================================
    def _load_and_crop_inner(self, image_path, mode="auto", bbox=None):
        img = Image.open(image_path).convert("RGB")
        if mode == "none":
            return img
        if mode == "bbox" and bbox is not None:
            return img.crop(bbox)

        # auto: crude black-frame detection; return original if fail
        arr = np.array(img)
        h, w = arr.shape[:2]
        black = (arr[:, :, 0] < 20) & (arr[:, :, 1] < 20) & (arr[:, :, 2] < 20)
        row_counts = black.sum(axis=1)
        col_counts = black.sum(axis=0)
        row_t = 0.4 * w
        col_t = 0.4 * h
        r_idx = np.where(row_counts > row_t)[0]
        c_idx = np.where(col_counts > col_t)[0]
        if len(r_idx) == 0 or len(c_idx) == 0:
            return img
        top, bottom = r_idx[0], r_idx[-1]
        left, right = c_idx[0], c_idx[-1]
        if bottom - top < h * 0.4 or right - left < w * 0.4:
            return img
        return img.crop((left, top, right + 1, bottom + 1))

    def _split_grid(
        self, img: Image.Image, rows: int, cols: int, return_debug: bool = False
    ):
        """
        Slice image into rows×cols cells; sample per cell:
          • median RGB
          • 5% / 95% quantiles for dark/bright stats (Exit / contamination heuristics)
        """
        w, h = img.size
        arr = np.array(img)
        x_edges = np.linspace(0, w, cols + 1).astype(int)
        y_edges = np.linspace(0, h, rows + 1).astype(int)
        mx = max(1, int((x_edges[1] - x_edges[0]) * 0.1))
        my = max(1, int((y_edges[1] - y_edges[0]) * 0.1))

        recs = []
        for y in range(rows):
            for x in range(cols):
                x0, x1 = x_edges[x], x_edges[x + 1]
                y0, y1 = y_edges[y], y_edges[y + 1]
                sx0, sx1 = x0 + mx, x1 - mx
                sy0, sy1 = y0 + my, y1 - my
                if sx1 <= sx0 or sy1 <= sy0:
                    sx0, sx1, sy0, sy1 = x0, x1, y0, y1
                crop = arr[sy0:sy1, sx0:sx1]
                if crop.size == 0:
                    med = (0, 0, 0)
                    dark_p = (0, 0, 0)
                    bright_p = (0, 0, 0)
                else:
                    flat = crop.reshape(-1, 3)
                    med = np.median(flat, axis=0)
                    dark_p = np.percentile(flat, 5, axis=0)
                    bright_p = np.percentile(flat, 95, axis=0)

                recs.append(
                    {
                        "x": x,
                        "y": y,
                        "avg_rgb": tuple(float(v) for v in med),
                        "extra_stats": {
                            "dark_p": tuple(float(v) for v in dark_p),
                            "bright_p": tuple(float(v) for v in bright_p),
                        },
                    }
                )

        dbg = None
        if return_debug:
            dbg = img.copy()
            d = ImageDraw.Draw(dbg)
            for xe in x_edges:
                d.line([(xe, 0), (xe, h)], fill=(255, 0, 0))
            for ye in y_edges:
                d.line([(0, ye), (w, ye)], fill=(255, 0, 0))
            try:
                font = ImageFont.load_default()
            except Exception:
                font = None
            if font:
                for r in recs:
                    x0, x1 = x_edges[r["x"]], x_edges[r["x"] + 1]
                    y0, y1 = y_edges[r["y"]], y_edges[r["y"] + 1]
                    cx = (x0 + x1) // 2
                    cy = (y0 + y1) // 2
                    d.text(
                        (cx, cy),
                        f"{r['x']},{r['y']}",
                        fill=(0, 0, 0),
                        font=font,
                        anchor="mm",
                    )
        return recs, dbg

    # =========================================================================
    # Debug overlay (show padding mapping; image/top coords)
    # =========================================================================
    def _compose_debug_overlay(
        self,
        img_inner: Image.Image,
        exp_rows: int,
        exp_cols: int,
        cont_rows: int,
        cont_cols: int,
        pad_top: int,
        pad_left: int,
        records_content: List[Dict[str, Any]],
    ) -> Image.Image:
        w, h = img_inner.size
        dbg = img_inner.copy()
        draw = ImageDraw.Draw(dbg)

        # content grid lines
        x_edges = np.linspace(0, w, cont_cols + 1).astype(int)
        y_edges = np.linspace(0, h, cont_rows + 1).astype(int)
        for xe in x_edges:
            draw.line([(xe, 0), (xe, h)], fill=(255, 0, 0))
        for ye in y_edges:
            draw.line([(0, ye), (w, ye)], fill=(255, 0, 0))

        try:
            font = ImageFont.load_default()
        except Exception:
            font = None

        for rec in records_content:
            x0, x1 = x_edges[rec["x"]], x_edges[rec["x"] + 1]
            y0, y1 = y_edges[rec["y"]], y_edges[rec["y"] + 1]
            cx = (x0 + x1) // 2
            cy = (y0 + y1) // 2
            draw.text(
                (cx, cy),
                f"{rec['x']},{rec['y']}→({rec['x']+pad_left},{rec['y']+pad_top})",
                fill=(0, 0, 0),
                font=font,
                anchor="mm",
            )
        draw.text(
            (5, 5),
            f"content={cont_cols}x{cont_rows} pad(L={pad_left},T={pad_top}) expected={exp_cols}x{exp_rows}",
            fill=(0, 0, 0),
            font=font,
            anchor="la",
        )
        return dbg

    # =========================================================================
    # Convert to downstream parking_map structure
    # =========================================================================
    def convert_to_parking_map_format(
        self,
        analysis: Dict[str, Any],
        grid_size: Tuple[int, int],
        coord_bottom_origin: Optional[bool] = None,
    ) -> List[Dict[str, Any]]:
        """
        Convert analysis results to a multi-level parking structure list.
        Corridors are derived from cached grid_data (top-origin); flip y if bottom-origin output requested.
        """
        if coord_bottom_origin is None:
            coord_bottom_origin = self._last_coord_bottom_origin

        rows, cols = grid_size
        building_name = analysis.get("building_name", "Unknown")
        total_levels = analysis.get("total_levels", 1)

        # corridors from top-origin grid_data; flip if needed
        gd = self._last_grid_data
        corridors_top = self._corridors_from_grid_data(gd, level=1) if gd else []

        corridors_out = []
        if gd:
            for c in corridors_top:
                cy = (rows - 1) - c["y"] if coord_bottom_origin else c["y"]
                corridors_out.append(
                    {
                        "corridor_id": c["corridor_id"],
                        "level": c["level"],
                        "x": c["x"],
                        "y": cy,
                        "direction": c["direction"],
                    }
                )

        parking = []
        for lvl in range(1, total_levels + 1):
            entrances = []
            for i, e in enumerate(analysis.get("entrances", []), 1):
                p = e.get("estimated_position", {"x": 0, "y": 0})
                entrances.append(
                    {
                        "entrance_id": e.get("entrance_id", f"E{i}"),
                        "x": p["x"],
                        "y": p["y"],
                        "type": e.get("type", "car"),
                    }
                )

            exits = []
            for i, e in enumerate(analysis.get("exits", []), 1):
                p = e.get("estimated_position", {"x": cols - 1, "y": 0})
                exits.append(
                    {
                        "exit_id": e.get("exit_id", f"X{i}"),
                        "x": p["x"],
                        "y": p["y"],
                        "level": lvl,
                    }
                )

            slots = []
            for i, s in enumerate(analysis.get("parking_slots", []), 1):
                p = s.get("estimated_position", {"x": 1, "y": 1})
                slots.append(
                    {
                        "slot_id": s.get("slot_id", f"S{i}"),
                        "status": s.get("status", "available"),
                        "x": p["x"],
                        "y": p["y"],
                        "level": lvl,
                        "vehicle_id": None,
                        "reserved_by": None,
                    }
                )

            ramps = []
            for i, r in enumerate(analysis.get("ramps", []), 1):
                p = r.get("estimated_position", {"x": 0, "y": 0})
                ramps.append(
                    {
                        "ramp_id": r.get("ramp_id", f"R{i}"),
                        "x": p["x"],
                        "y": p["y"],
                        "level": lvl,
                    }
                )

            parking.append(
                {
                    "building": building_name,
                    "level": lvl,
                    "size": {"rows": rows, "cols": cols},
                    "entrances": entrances,
                    "exits": exits,
                    "slots": slots,
                    "corridors": corridors_out if lvl == 1 else [],
                    "walls": self._generate_basic_walls(lvl, grid_size),
                    "ramps": ramps,
                }
            )
        return parking

    # =========================================================================
    # Corridor extraction (top-origin)
    # =========================================================================
    def _corridors_from_grid_data(
        self, grid_data: Dict[str, Any], level: int
    ) -> List[Dict[str, Any]]:
        out = []
        n = 0
        for c in grid_data["cells"]:
            if c["color"] == "white" or "corridor" in (c.get("text") or "").lower():
                n += 1
                out.append(
                    {
                        "corridor_id": f"C{n}",
                        "level": level,
                        "x": c["x"],
                        "y": c["y"],
                        "direction": "both",
                    }
                )
        return out
        # NOTE: watch for stray quote chars if copy/pasting.

    # =========================================================================
    # walls fallback
    # =========================================================================
    def _generate_basic_walls(
        self, level: int, grid_size: tuple
    ) -> List[Dict[str, Any]]:
        rows, cols = grid_size
        return [
            {
                "wall_id": f"W{level}1",
                "level": level,
                "points": [[0, 0], [cols - 1, 0]],
            },
            {
                "wall_id": f"W{level}2",
                "level": level,
                "points": [[cols - 1, 0], [cols - 1, rows - 1]],
            },
            {
                "wall_id": f"W{level}3",
                "level": level,
                "points": [[cols - 1, rows - 1], [0, rows - 1]],
            },
            {
                "wall_id": f"W{level}4",
                "level": level,
                "points": [[0, rows - 1], [0, 0]],
            },
        ]

    # =========================================================================
    # Debug export
    # =========================================================================
    def dump_cells_rgb(
        self, path: Optional[str] = None, coord_bottom_origin: Optional[bool] = None
    ):
        """
        Print/export cached grid color classification. Optionally convert to bottom-origin coords.
        """
        gd = self._last_grid_data
        if not gd:
            print("No grid_data.")
            return
        if coord_bottom_origin is None:
            coord_bottom_origin = self._last_coord_bottom_origin
        rows = gd["rows"]

        lines = ["x,y,color,text"]
        for c in gd["cells"]:
            x, y = c["x"], c["y"]
            if coord_bottom_origin:
                y = (rows - 1) - y
            lines.append(f"{x},{y},{c['color']},{c.get('text','')}")
        out = "\n".join(lines)
        if path:
            with open(path, "w", encoding="utf-8") as f:
                f.write(out)
        print(out)

    def render_label_debug_png(
        self,
        path: str,
        cell_size: int = 40,
        coord_bottom_origin: Optional[bool] = None,
        label_swap: Optional[str] = None,
    ):
        """
        Render a pure-color debug grid from cached data.
        - coord_bottom_origin=True draws bottom-origin labels
        - label_swap='yx' swaps label order for human cross-checking
        """
        gd = self._last_grid_data
        if not gd:
            print("No grid_data.")
            return
        if coord_bottom_origin is None:
            coord_bottom_origin = self._last_coord_bottom_origin
        if label_swap is None:
            label_swap = self._last_label_swap

        rows, cols = gd["rows"], gd["cols"]
        w, h = cols * cell_size, rows * cell_size
        img = Image.new("RGB", (w, h), (255, 255, 255))
        d = ImageDraw.Draw(img)
        try:
            font = ImageFont.load_default()
        except Exception:
            font = None

        def col(b):
            return {
                "black": (0, 0, 0),
                "white": (240, 240, 240),
                "green": (0, 176, 80),
                "orange": (240, 176, 80),
                "purple": (128, 64, 240),
                "pink": (240, 80, 176),
                "gray": (160, 160, 160),
            }.get(b, (255, 255, 255))

        for c in gd["cells"]:
            x_img, y_img = c["x"], c["y"]
            x_draw = x_img
            y_draw = y_img  # image (top-origin) coords for drawing

            # cell rect
            x0, y0 = x_draw * cell_size, y_draw * cell_size
            x1, y1 = x0 + cell_size, y0 + cell_size
            d.rectangle([x0, y0, x1, y1], fill=col(c["color"]), outline=(0, 0, 0))

            if font:
                # label coords: optionally bottom-origin
                if coord_bottom_origin:
                    y_lab = (rows - 1) - y_img
                else:
                    y_lab = y_img
                x_lab = x_img

                # optional swap (text only)
                if label_swap == "yx":
                    txt = f"{y_lab},{x_lab}"
                else:
                    txt = f"{x_lab},{y_lab}"

                d.text(
                    (x0 + cell_size // 2, y0 + cell_size // 2),
                    txt,
                    fill=(0, 0, 0),
                    font=font,
                    anchor="mm",
                )

        img.save(path)
        print(f"debug grid saved: {path}")


# === end class ===
