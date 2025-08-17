"""
Pathfinding router for parking lot navigation APIs

This module contains all pathfinding-related API endpoints including
shortest path calculation and nearest slot finding.
"""

from fastapi import APIRouter, Query, HTTPException
from typing import Optional, Dict, Any
import logging
from app.parking.utils import get_map_data
from .path_planner import PathPlanner

router = APIRouter(prefix="/pathfinding", tags=["pathfinding"])


@router.get(
    "/shortest-path",
    responses={
        200: {
            "description": "Return the shortest path point set and distance",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "path": [(1, 1), (5, 1), (5, 5)],
                        "distance": 6.0,
                        "path_points": 3,
                    }
                }
            },
        },
        400: {
            "description": "Invalid parameters or no path found",
            "content": {"application/json": {"example": {"detail": "No path found."}}},
        },
    },
)
def get_shortest_path(
    start: str = Query(
        ..., description="Start point in 'level,x,y' format.", example="1,0,3"
    ),
    end: str = Query(
        ..., description="End point in 'level,x,y' format.", example="2,2,2"
    ),
    building_name: Optional[str] = Query(None, description="Building name"),
    map_id: Optional[str] = Query(None, description="Map ID"),
):
    """
    🛣️ Find the shortest path between two points in a parking lot

    This endpoint calculates the optimal route between any two points in the parking lot,
    considering corridors, entrances, exits, slots, and ramps between levels.

    **Parameters:**
    - **start**: Starting coordinate in format "level,x,y" (e.g., "1,0,3")
    - **end**: Ending coordinate in format "level,x,y" (e.g., "2,2,2")
    - **building_name**: (optional) Building name to search for
    - **map_id**: (optional) Map ID to search for

    **Examples:**
    - `GET /pathfinding/shortest-path?start=1,0,3&end=1,2,2&map_id=999999`
    - `GET /pathfinding/shortest-path?start=1,0,0&end=2,5,5&building_name=westfield sydney`

    **Returns:**
    - Optimal path as a list of coordinates
    - Total distance of the path
    - Number of path points
    """
    try:
        # Get map data
        map_data = get_map_data(map_id, building_name)
        if not map_data:
            raise HTTPException(status_code=404, detail="Map not found")

        parking_map = map_data.get("parking_map", [])
        if not parking_map:
            raise HTTPException(
                status_code=404,
                detail="No parking map data found for the specified map.",
            )

        # Parse start/end points
        def parse_point_with_level(s: str):
            parts = s.split(",")
            if len(parts) != 3:
                raise ValueError("Point must be in 'level,x,y' format.")
            level, x, y = int(parts[0]), float(parts[1]), float(parts[2])
            return (level, x, y)

        start_pt = parse_point_with_level(start)
        end_pt = parse_point_with_level(end)

        # Create path planner and find shortest path
        planner = PathPlanner(parking_map)
        path, dist = planner.find_path(start_pt, end_pt)

        if not path:
            raise HTTPException(
                status_code=404, detail="No path found between the specified points."
            )

        return {
            "success": True,
            "map_id": map_data.get("_id"),
            "building_name": map_data.get("building_name"),
            "source": map_data.get("source", "unknown"),
            "start": start_pt,
            "end": end_pt,
            "path": path,
            "distance": dist,
            "path_points": len(path),
        }

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"An unexpected error occurred: {e}"
        )


@router.get(
    "/nearest-slot/{point_id}",
    responses={
        200: {
            "description": "Find Nearest Slot To Point Auto",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "source_point": {
                            "type": "entrance",
                            "id": "E1",
                            "data": {
                                "entrance_id": "E1",
                                "x": 0,
                                "y": 3,
                                "type": "car",
                                "level": 1,
                            },
                        },
                        "nearest_slot": {
                            "slot_id": "1B",
                            "status": "available",
                            "x": 2,
                            "y": 3,
                            "level": 1,
                        },
                        "direct_distance": 2.0,
                        "path": [[1, 0, 3], [1, 1, 3], [1, 2, 3]],
                        "path_distance": 2.0,
                        "path_points": 3,
                    }
                }
            },
        },
        400: {
            "description": "Invalid parameters",
            "content": {
                "application/json": {
                    "examples": {
                        "PointNotFound": {
                            "summary": "Point not found",
                            "value": {"detail": "Point 'E1' not found"},
                        },
                        "NoSlotsAvailable": {
                            "summary": "No available slots",
                            "value": {"detail": "No available parking slots found"},
                        },
                    }
                }
            },
        },
        404: {"description": "Map not found"},
    },
)
def find_nearest_slot_to_point_auto(
    point_id: str,
    map_id: Optional[str] = Query(None, description="Map ID"),
    building_name: Optional[str] = Query(None, description="Building name"),
):
    """
    🎯 Find the nearest available parking slot to a specific point (Auto-detect type)

    This endpoint automatically detects the point type based on the point_id naming convention:
    - Entrances: E1, E2, BE1, BE2, etc. (E=Entrance, BE=Building Entrance)
    - Exits: X1, X2, etc. (X=Exit)
    - Ramps: R1_up, R1_down, etc. (R=Ramp)

    **Examples:**
    - `GET /pathfinding/nearest-slot/E1?map_id=999999`
    - `GET /pathfinding/nearest-slot/BE2?level=2&map_id=999999`
    - `GET /pathfinding/nearest-slot/X1?building_name=westfield sydney`
    - `GET /pathfinding/nearest-slot/R1_up?map_id=999999`

    **Returns:**
    - Nearest available parking slot
    - Direct distance to the slot
    - Optimal path from the point to the slot
    - Total path distance and number of path points
    """
    try:
        map_data = get_map_data(map_id, building_name)
        if not map_data:
            raise HTTPException(status_code=404, detail="Map not found")
        parking_map = map_data.get("parking_map", [])
        planner = PathPlanner(parking_map)

        # 1. Auto-detect point type
        point_type = None
        if point_id.upper().startswith(("E", "BE")):
            point_type = "entrance"
        elif point_id.upper().startswith("X"):
            point_type = "exit"
        elif point_id.upper().startswith("R"):
            point_type = "ramp"
        else:
            raise HTTPException(
                status_code=400,
                detail=f"Unable to determine point type for '{point_id}'",
            )

        # 2. Find point info
        point = None
        for level_data in parking_map:
            points = level_data.get(point_type + "s", [])
            for p in points:
                if p.get(f"{point_type}_id") == point_id:
                    point = p
                    break
            if point:
                break
        if not point:
            raise HTTPException(status_code=404, detail=f"Point '{point_id}' not found")
        point_node = (point.get("level", 1), point["x"], point["y"])
        point_level = point.get("level", 1)

        # 3. Gather available slots by level
        same_level_slots = []
        other_level_slots = []
        for level_data in parking_map:
            for slot in level_data.get("slots", []):
                if slot.get("status", "available").lower() in ["available", "free"]:
                    if slot.get("level", 1) == point_level:
                        same_level_slots.append(slot)
                    else:
                        other_level_slots.append(slot)

        # 4. If same-level slots exist, find the nearest one
        candidates = same_level_slots if same_level_slots else other_level_slots
        if same_level_slots:
            nearest_slot = None
            min_dist = float("inf")
            best_path = None
            for slot in candidates:
                slot_node = (slot.get("level", 1), slot["x"], slot["y"])
                path, dist = planner.find_path(point_node, slot_node)
                if path and dist < min_dist:
                    min_dist = dist
                    nearest_slot = slot
                    best_path = path
            if not nearest_slot:
                raise HTTPException(
                    status_code=400, detail="No available slot found near the point"
                )
            return {
                "success": True,
                "map_id": map_data.get("_id"),
                "building_name": map_data.get("building_name"),
                "source": map_data.get("source", "unknown"),
                "source_point": {"type": point_type, "id": point_id, "data": point},
                "nearest_slot": nearest_slot,
                "direct_distance": min_dist,
                "path": best_path,
                "path_distance": min_dist,
                "path_points": len(best_path) if best_path else 0,
            }
        # 5. If no same-level slots, find the nearest ramp, then the nearest slot to the ramp's destination
        else:
            # Find all ramps on the same level as the point
            ramps = []
            for level_data in parking_map:
                if level_data.get("level") == point_level:
                    ramps.extend(level_data.get("ramps", []))
            if not ramps:
                raise HTTPException(
                    status_code=400,
                    detail="No ramps found on this level and no available slot on this level",
                )
            nearest_ramp = None
            min_ramp_dist = float("inf")
            path_to_ramp = None
            for ramp in ramps:
                ramp_node = (ramp.get("level", 1), ramp["x"], ramp["y"])
                path, dist = planner.find_path(point_node, ramp_node)
                if path and dist < min_ramp_dist:
                    min_ramp_dist = dist
                    nearest_ramp = ramp
                    path_to_ramp = path
            if not nearest_ramp:
                raise HTTPException(
                    status_code=400, detail="No accessible ramp found from the point"
                )
            # Find available slots on the ramp's destination level
            ramp_dest_level = nearest_ramp.get("to_level")
            ramp_dest_x = nearest_ramp.get("to_x")
            ramp_dest_y = nearest_ramp.get("to_y")
            ramp_dest_node = (ramp_dest_level, ramp_dest_x, ramp_dest_y)
            dest_level_slots = [
                slot
                for slot in other_level_slots
                if slot.get("level", 1) == ramp_dest_level
            ]
            if not dest_level_slots:
                raise HTTPException(
                    status_code=400,
                    detail="No available slot found on the ramp's destination level",
                )
            nearest_slot = None
            min_slot_dist = float("inf")
            path_from_ramp = None
            for slot in dest_level_slots:
                slot_node = (slot.get("level", 1), slot["x"], slot["y"])
                path, dist = planner.find_path(ramp_dest_node, slot_node)
                if path and dist < min_slot_dist:
                    min_slot_dist = dist
                    nearest_slot = slot
                    path_from_ramp = path
            if not nearest_slot:
                raise HTTPException(
                    status_code=400,
                    detail="No available slot found from ramp destination",
                )
            # Combine path: point -> ramp + ramp destination -> slot
            full_path = (
                path_to_ramp + path_from_ramp[1:] if path_from_ramp else path_to_ramp
            )
            total_dist = min_ramp_dist + min_slot_dist
            return {
                "success": True,
                "map_id": map_data.get("_id"),
                "building_name": map_data.get("building_name"),
                "source": map_data.get("source", "unknown"),
                "source_point": {"type": point_type, "id": point_id, "data": point},
                "nearest_slot": nearest_slot,
                "direct_distance": total_dist,
                "path": full_path,
                "path_distance": total_dist,
                "path_points": len(full_path) if full_path else 0,
                "ramp_used": nearest_ramp,
            }
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error finding nearest slot: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to find nearest slot: {str(e)}"
        )


@router.get(
    "/route-to-nearest-slot",
    responses={
        200: {
            "description": "Find route from entrance to the nearest available slot near a target point",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "entrance": {
                            "entrance_id": "E1",
                            "x": 0,
                            "y": 3,
                            "type": "car",
                            "level": 1,
                        },
                        "target_point": {
                            "type": "building",
                            "id": "BE2",
                            "data": {
                                "entrance_id": "BE2",
                                "x": 3,
                                "y": 0,
                                "type": "building",
                                "level": 2,
                            },
                        },
                        "nearest_slot": {
                            "slot_id": "2C",
                            "status": "available",
                            "x": 3,
                            "y": 2,
                            "level": 2,
                        },
                        "route_from_entrance_to_slot": {
                            "path": [[1, 0, 3], [1, 1, 3], [2, 3, 2]],
                            "distance": 8.0,
                            "path_points": 9,
                        },
                        "route_from_slot_to_target": {
                            "path": [[2, 3, 0], [2, 3, 1], [2, 3, 2]],
                            "distance": 2.0,
                            "path_points": 3,
                        },
                    }
                }
            },
        },
        400: {"description": "Invalid parameters or no slot found"},
        404: {"description": "Map or point not found"},
    },
)
def route_to_nearest_slot(
    entrance_id: str = Query(
        ..., description="Entrance ID where user enters, e.g. E1, BE2"
    ),
    target_point_id: str = Query(
        ..., description="Target point ID, e.g. BE2, X1, R1_up, etc."
    ),
    map_id: Optional[str] = Query(None, description="Map ID"),
    building_name: Optional[str] = Query(None, description="Building name"),
):
    """
    🚗 user specifies entrance and target point, system finds the nearest available slot near the target point, and returns the optimal route from the entrance to the slot.
    """
    try:
        # Get map data
        logging.info(
            f"Route to nearest slot request - entrance_id: {entrance_id}, target_point_id: {target_point_id}, building_name: {building_name}, map_id: {map_id}"
        )

        map_data = get_map_data(map_id, building_name)
        if not map_data:
            logging.error(
                f"Map not found for building_name: {building_name}, map_id: {map_id}"
            )
            raise HTTPException(status_code=404, detail="Map not found")

        parking_map = map_data.get("parking_map", [])
        logging.info(
            f"Found map data, building: {map_data.get('building_name')}, levels: {len(parking_map)}"
        )

        planner = PathPlanner(parking_map)

        # 1. Find entrance information
        entrance = None
        for level_data in parking_map:
            for e in level_data.get("entrances", []):
                if e.get("entrance_id") == entrance_id:
                    entrance = e
                    break
            if entrance:
                break
        if not entrance:
            logging.error(f"Entrance '{entrance_id}' not found in map")
            raise HTTPException(
                status_code=404, detail=f"Entrance '{entrance_id}' not found"
            )

        logging.info(f"Found entrance: {entrance}")
        entrance_node = (entrance.get("level", 1), entrance["x"], entrance["y"])

        # 2. Automatically identify target_point type
        point_type = None
        if target_point_id.upper().startswith(("E", "BE")):
            point_type = "entrance"
        elif target_point_id.upper().startswith("X"):
            point_type = "exit"
        elif target_point_id.upper().startswith("R"):
            point_type = "ramp"
        else:
            logging.error(f"Unable to determine point type for '{target_point_id}'")
            raise HTTPException(
                status_code=400,
                detail=f"Unable to determine point type for '{target_point_id}'",
            )

        logging.info(
            f"Identified target point type: {point_type} for ID: {target_point_id}"
        )

        # 3. Find target_point information
        target_point = None
        for level_data in parking_map:
            points = level_data.get(point_type + "s", [])
            for p in points:
                if p.get(f"{point_type}_id") == target_point_id:
                    target_point = p
                    break
            if target_point:
                break
        if not target_point:
            logging.error(f"Target point '{target_point_id}' not found in map")
            raise HTTPException(
                status_code=404, detail=f"Target point '{target_point_id}' not found"
            )

        logging.info(f"Found target point: {target_point}")
        target_node = (
            target_point.get("level", 1),
            target_point["x"],
            target_point["y"],
        )
        target_level = target_point.get("level", 1)

        # 4. Find the nearest available slot near the target point
        # Priority: first search slots on the same level as the target point, if none, then search other levels
        same_level_slots = []
        other_level_slots = []
        for level_data in parking_map:
            for slot in level_data.get("slots", []):
                if slot.get("status", "available").lower() in ["available", "free"]:
                    if slot.get("level", 1) == target_level:
                        same_level_slots.append(slot)
                    else:
                        other_level_slots.append(slot)

        # Log the available slots for debugging
        logging.info(
            f"Found {len(same_level_slots)} same-level slots and {len(other_level_slots)} other-level slots"
        )

        candidates = same_level_slots if same_level_slots else other_level_slots
        if not candidates:
            logging.error("No available parking slots found")
            raise HTTPException(
                status_code=400, detail="No available parking spots found"
            )

        if candidates:
            nearest_slot = None
            min_dist = float("inf")
            best_path = None

            # Find nearest slot to target
            for slot in candidates:
                try:
                    slot_node = (slot.get("level", 1), slot["x"], slot["y"])
                    path, dist = planner.find_path(target_node, slot_node)

                    if path and dist < min_dist:
                        min_dist = dist
                        nearest_slot = slot
                        best_path = path
                except Exception as e:
                    logging.error(
                        f"Error finding path to slot {slot.get('slot_id', 'unknown')}: {e}"
                    )
                    continue

            if not nearest_slot:
                logging.error("Could not find path to any available slot")
                raise HTTPException(
                    status_code=400,
                    detail="No available slot found near the target point",
                )

            # Find path from entrance to slot
            try:
                slot_node = (
                    nearest_slot.get("level", 1),
                    nearest_slot["x"],
                    nearest_slot["y"],
                )
                path_from_entrance, dist_from_entrance = planner.find_path(
                    entrance_node, slot_node
                )

                if not path_from_entrance:
                    logging.error("No path found from entrance to nearest slot")
                    raise HTTPException(
                        status_code=400,
                        detail="No route found from entrance to nearest slot",
                    )

                # Format paths for output - convert tuples to lists for JSON serialization
                formatted_path_from_entrance = []
                for point in path_from_entrance:
                    if isinstance(point, tuple) and len(point) >= 3:
                        formatted_path_from_entrance.append(
                            [point[0], point[1], point[2]]
                        )

                # Calculate path from slot to target (in correct order)
                # Special handling for slot as starting point
                # 1. First find the nearest corridor point to the slot
                slot_level = nearest_slot.get("level", 1)
                slot_coord = (nearest_slot["x"], nearest_slot["y"])
                slot_node = (slot_level, nearest_slot["x"], nearest_slot["y"])

                # Get all corridor points from the map
                corridor_points = []
                for level_data in parking_map:
                    if level_data.get("level") == slot_level:
                        for corridor in level_data.get("corridors", []):
                            for point in corridor["points"]:
                                corridor_points.append((slot_level, point[0], point[1]))

                # Find the nearest corridor point to the slot
                nearest_corridor = None
                min_corridor_dist = float("inf")
                for corridor_point in corridor_points:
                    corridor_coord = (corridor_point[1], corridor_point[2])
                    # Check if this is actually a corridor (not a slot or other point)
                    is_slot = False
                    for level_data in parking_map:
                        if level_data.get("level") == slot_level:
                            for slot in level_data.get("slots", []):
                                if (
                                    slot["x"] == corridor_coord[0]
                                    and slot["y"] == corridor_coord[1]
                                ):
                                    is_slot = True
                                    break
                    if is_slot:
                        continue

                    # Only consider directly adjacent corridor points
                    dx = abs(slot_coord[0] - corridor_coord[0])
                    dy = abs(slot_coord[1] - corridor_coord[1])
                    if (dx == 1 and dy == 0) or (
                        dx == 0 and dy == 1
                    ):  # Adjacent horizontally or vertically
                        dist = dx + dy  # Manhattan distance for adjacent points
                        if dist < min_corridor_dist:
                            min_corridor_dist = dist
                            nearest_corridor = corridor_point

                if not nearest_corridor:
                    logging.error(
                        f"No adjacent corridor found for slot {nearest_slot.get('slot_id')}"
                    )
                    raise HTTPException(
                        status_code=400,
                        detail="No adjacent corridor found for parking slot",
                    )

                # Now compute path from nearest corridor to target
                path_from_corridor_to_target, dist_from_corridor_to_target = (
                    planner.find_path(nearest_corridor, target_node)
                )

                if not path_from_corridor_to_target:
                    logging.error(
                        f"No path found from corridor {nearest_corridor} to target {target_node}"
                    )
                    raise HTTPException(
                        status_code=400, detail="No route found from slot to target"
                    )

                # Prepend the slot to the path
                path_from_slot_to_target = [slot_node] + path_from_corridor_to_target
                dist_from_slot_to_target = (
                    dist_from_corridor_to_target + min_corridor_dist
                )

                # Format the path
                formatted_path_from_slot_to_target = []
                for point in path_from_slot_to_target:
                    if isinstance(point, tuple) and len(point) >= 3:
                        formatted_path_from_slot_to_target.append(
                            [point[0], point[1], point[2]]
                        )

                return {
                    "success": True,
                    "entrance": entrance,
                    "target_point": {
                        "type": point_type,
                        "id": target_point_id,
                        "data": target_point,
                    },
                    "nearest_slot": nearest_slot,
                    "route_from_entrance_to_slot": {
                        "path": formatted_path_from_entrance,
                        "distance": dist_from_entrance,
                        "path_points": len(formatted_path_from_entrance),
                    },
                    "route_from_slot_to_target": {
                        "path": formatted_path_from_slot_to_target,
                        "distance": dist_from_slot_to_target,
                        "path_points": len(formatted_path_from_slot_to_target),
                    },
                }
            except Exception as e:
                logging.error(f"Error calculating path from entrance to slot: {e}")
                raise HTTPException(
                    status_code=500, detail=f"Error calculating route: {str(e)}"
                )
        else:
            # Try to find path using ramps if no slots on same level
            logging.info(
                "No slots found on current level, checking ramps for other levels"
            )
            # Find all ramps on the same level as the target point
            ramps = []
            for level_data in parking_map:
                if level_data.get("level") == target_level:
                    ramps.extend(level_data.get("ramps", []))
            if not ramps:
                raise HTTPException(
                    status_code=400,
                    detail="No ramps found on this level and no available slot on this level",
                )
            nearest_ramp = None
            min_ramp_dist = float("inf")
            path_to_ramp = None
            for ramp in ramps:
                ramp_node = (ramp.get("level", 1), ramp["x"], ramp["y"])
                path, dist = planner.find_path(target_node, ramp_node)
                if path and dist < min_ramp_dist:
                    min_ramp_dist = dist
                    nearest_ramp = ramp
                    path_to_ramp = path
            if not nearest_ramp:
                raise HTTPException(
                    status_code=400,
                    detail="No accessible ramp found from the target point",
                )
            # Find available slots on the ramp's destination level
            ramp_dest_level = nearest_ramp.get("to_level")
            ramp_dest_x = nearest_ramp.get("to_x")
            ramp_dest_y = nearest_ramp.get("to_y")
            ramp_dest_node = (ramp_dest_level, ramp_dest_x, ramp_dest_y)
            dest_level_slots = [
                slot
                for slot in other_level_slots
                if slot.get("level", 1) == ramp_dest_level
            ]
            if not dest_level_slots:
                raise HTTPException(
                    status_code=400,
                    detail="No available slot found on the ramp's destination level",
                )
            nearest_slot = None
            min_slot_dist = float("inf")
            path_from_ramp = None
            for slot in dest_level_slots:
                slot_node = (slot.get("level", 1), slot["x"], slot["y"])
                path, dist = planner.find_path(ramp_dest_node, slot_node)
                if path and dist < min_slot_dist:
                    min_slot_dist = dist
                    nearest_slot = slot
                    path_from_ramp = path
            if not nearest_slot:
                raise HTTPException(
                    status_code=400,
                    detail="No available slot found from ramp destination",
                )
            # Combine path: target -> ramp + ramp destination -> slot
            full_path = (
                path_to_ramp + path_from_ramp[1:] if path_from_ramp else path_to_ramp
            )
            total_dist = min_ramp_dist + min_slot_dist
            path_from_entrance, dist_from_entrance = planner.find_path(
                entrance_node,
                (nearest_slot.get("level", 1), nearest_slot["x"], nearest_slot["y"]),
            )
            return {
                "success": True,
                "entrance": entrance,
                "target_point": {
                    "type": point_type,
                    "id": target_point_id,
                    "data": target_point,
                },
                "nearest_slot": nearest_slot,
                "route_from_entrance_to_slot": {
                    "path": path_from_entrance,
                    "distance": dist_from_entrance,
                    "path_points": len(path_from_entrance) if path_from_entrance else 0,
                },
                "route_from_slot_to_target": {
                    "path": full_path,
                    "distance": total_dist,
                    "path_points": len(full_path) if full_path else 0,
                },
                "nearest_ramp_used": nearest_ramp,
            }
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error in route_to_nearest_slot: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to find route: {str(e)}")


@router.get(
    "/destinations",
    responses={
        200: {
            "description": "Return list of available destination points",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "destinations": [
                            "Westfield Sydney",
                            "Building Entrance (BE1)",
                            "Building Entrance (BE2)",
                            "Exit (X1)",
                            "Exit (X2)",
                        ],
                    }
                }
            },
        },
        400: {"description": "Invalid parameters"},
        404: {"description": "Map not found"},
    },
)
def get_available_destinations(
    entrance_id: Optional[str] = Query(
        None, description="Optional entrance ID to filter destinations"
    ),
    map_id: Optional[str] = Query(None, description="Map ID"),
    building_name: Optional[str] = Query(None, description="Building name"),
):
    """
    🎯 Get list of available destination points.

    This endpoint returns a list of available destinations that users can select after scanning
    the entrance QR code. The list includes building entrances, exits, and other points of interest.

    If an entrance_id is provided, the destinations are filtered to show only those relevant
    to the specified entrance (e.g., on the same level or accessible from that entrance).

    **Examples:**
    - `GET /pathfinding/destinations` - Get all destinations
    - `GET /pathfinding/destinations?entrance_id=E1` - Get destinations accessible from entrance E1
    - `GET /pathfinding/destinations?building_name=Westfield%20Sydney` - Get destinations in Westfield Sydney

    **Returns:**
    - List of destination names that can be shown to the user for selection
    """
    try:
        # Get map data
        map_data = get_map_data(map_id, building_name)
        if not map_data:
            raise HTTPException(status_code=404, detail="Map not found")

        parking_map = map_data.get("parking_map", [])

        # Find the building name
        building_names = set()
        for level_data in parking_map:
            if "building" in level_data:
                building_names.add(level_data["building"])

        # Collect all destination points
        destinations = []

        # Add building name as a destination
        destinations.extend(list(building_names))

        # Find entrance source level if entrance_id is provided
        entrance_level = None
        if entrance_id:
            for level_data in parking_map:
                for entrance in level_data.get("entrances", []):
                    if entrance.get("entrance_id") == entrance_id:
                        entrance_level = level_data.get("level")
                        break
                if entrance_level is not None:
                    break

        # Add building entrances
        for level_data in parking_map:
            # Filter by level if entrance_id was provided and found
            if entrance_level is not None and level_data.get("level") != entrance_level:
                # Only include destinations from other levels if there's a ramp connection
                has_ramp_to_level = False
                for ramp in level_data.get("ramps", []):
                    if ramp.get("to_level") == entrance_level:
                        has_ramp_to_level = True
                        break

                if not has_ramp_to_level:
                    continue

            # Add building entrances from this level
            for entrance in level_data.get("entrances", []):
                if entrance.get("type") == "building":
                    entrance_id = entrance.get("entrance_id")
                    level_num = level_data.get("level", 1)
                    destinations.append(f"Building Entrance ({entrance_id})")

            # Add exits from this level
            for exit_point in level_data.get("exits", []):
                exit_id = exit_point.get("exit_id")
                level_num = level_data.get("level", 1)
                destinations.append(f"Exit ({exit_id})")

        return {"success": True, "destinations": destinations}

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error getting destinations: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to get destinations: {str(e)}"
        )


@router.get(
    "/nearest-exit-to-slot",
    responses={
        200: {
            "description": "Find the nearest exit to a parking slot",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "slot": {
                            "slot_id": "1A",
                            "x": 8,
                            "y": 3,
                            "level": 1,
                            "status": "occupied",
                        },
                        "nearest_exit": {"exit_id": "X1", "x": 15, "y": 8, "level": 1},
                        "distance": 12.5,
                        "path": [[1, 8, 3], [1, 10, 3], [1, 15, 8]],
                        "path_points": 3,
                        "map_info": {
                            "building_name": "Example Building",
                            "map_id": "12345",
                        },
                    }
                }
            },
        },
        400: {
            "description": "Invalid parameters",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidSlotId": {
                            "summary": "Parking slot not found",
                            "value": {"detail": "Parking slot '1Z' not found"},
                        }
                    }
                }
            },
        },
        404: {
            "description": "Map or exit not found",
            "content": {
                "application/json": {
                    "examples": {
                        "MapNotFound": {
                            "summary": "Building or map not found",
                            "value": {"detail": "Map not found"},
                        },
                        "NoExitsFound": {
                            "summary": "No exits available",
                            "value": {"detail": "No exits found in the parking map"},
                        },
                        "NoPathFound": {
                            "summary": "No route to any exit",
                            "value": {"detail": "No path found from slot to any exit"},
                        },
                    }
                }
            },
        },
    },
)
def get_nearest_exit_to_slot(
    slot_id: str = Query(..., description="Parking slot ID", example="1A"),
    building_name: Optional[str] = Query(None, description="Building name"),
    map_id: Optional[str] = Query(None, description="Map ID"),
):
    """
    Find the nearest exit to a parking slot

    This endpoint finds the closest exit to a given parking slot and calculates
    the optimal path from the slot to that exit. This is useful for directing
    users from their parking spot to the nearest exit when leaving.
    """
    try:
        # Get map data
        map_data = get_map_data(map_id, building_name)
        if not map_data:
            raise HTTPException(status_code=404, detail="Map not found")

        parking_map = map_data.get("parking_map", [])
        if not parking_map:
            raise HTTPException(
                status_code=404,
                detail="No parking map data found for the specified map.",
            )

        # Create path planner
        planner = PathPlanner(parking_map)

        # Find the slot first to validate it exists
        target_slot = None
        slot_level = None
        for level_data in parking_map:
            for slot in level_data.get("slots", []):
                if slot.get("slot_id") == slot_id:
                    target_slot = slot
                    slot_level = level_data.get("level", 1)
                    break
            if target_slot:
                break

        if not target_slot:
            raise HTTPException(
                status_code=400, detail=f"Parking slot '{slot_id}' not found"
            )

        # Check if any exits exist
        exits_exist = False
        for level_data in parking_map:
            if level_data.get("exits"):
                exits_exist = True
                break

        if not exits_exist:
            raise HTTPException(
                status_code=404, detail="No exits found in the parking map"
            )

        # Find nearest exit to the slot
        nearest_exit, distance, path = planner.find_nearest_exit_to_slot(slot_id)

        if not nearest_exit or not path:
            raise HTTPException(
                status_code=404, detail="No path found from slot to any exit"
            )

        # Prepare slot information with level
        slot_info = target_slot.copy()
        slot_info["level"] = slot_level

        # Prepare response
        response_data = {
            "success": True,
            "slot": slot_info,
            "nearest_exit": nearest_exit,
            "distance": round(distance, 2),
            "path": path,
            "path_points": len(path),
            "map_info": {
                "building_name": map_data.get("building_name"),
                "map_id": str(map_data.get("_id", "")),
            },
        }

        return response_data

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error finding nearest exit to slot: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to find nearest exit to slot: {str(e)}"
        )
