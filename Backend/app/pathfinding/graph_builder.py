"""
Graph builder for parking lot pathfinding

This module contains functions for building and connecting graphs
representing parking lot layouts for pathfinding algorithms.
"""

from typing import Dict, List, Tuple, Any
from .algorithms import euclidean_distance


def build_graph_from_corridors(corridors: List[Dict]) -> Dict:
    """
    Convert corridor data to a directed graph structure

    Args:
        corridors: List of corridor objects with points and direction

    Returns:
        Dict: Graph representation as adjacency list
    """
    graph = {}
    for corridor in corridors:
        pts = corridor["points"]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]

            # Check if points are valid for connection (should be adjacent horizontally or vertically)
            # Points should differ in exactly one coordinate by exactly 1
            dx = abs(a[0] - b[0])
            dy = abs(a[1] - b[1])

            # Only connect points that are horizontally or vertically adjacent (not diagonal)
            if (dx == 1 and dy == 0) or (dx == 0 and dy == 1):
                # Calculate actual distance
                weight = euclidean_distance(a, b)

                if corridor["direction"] in ["forward", "both"]:
                    graph.setdefault(a, []).append((b, weight))
                if corridor["direction"] in ["backward", "both"]:
                    graph.setdefault(b, []).append((a, weight))
            else:
                # Log warning if corridor points are not adjacent
                import logging

                logging.warning(
                    f"Corridor points {a} and {b} are not adjacent (dx={dx}, dy={dy}). Connection skipped."
                )

    return graph


def connect_entrances_exits_to_corridors(
    graph: Dict, entrances: List[Tuple], exits: List[Tuple], corridors: List[Dict]
) -> None:
    """
    Connect entrances and exits to the nearest corridor points

    Args:
        graph: Graph to modify
        entrances: List of entrance points
        exits: List of exit points
        corridors: List of corridor objects
    """
    # Connect entrances (bidirectional)
    for e in entrances:
        min_dist, min_pt = float("inf"), None
        for corridor in corridors:
            for pt in corridor["points"]:
                d = euclidean_distance(e, pt)
                if d < min_dist:
                    min_dist, min_pt = d, pt
        if min_pt:
            graph.setdefault(e, []).append((min_pt, 1))
            graph.setdefault(min_pt, []).append((e, 1))

    # Connect exits (unidirectional from corridor to exit)
    for x in exits:
        min_dist, min_pt = float("inf"), None
        for corridor in corridors:
            for pt in corridor["points"]:
                d = euclidean_distance(x, pt)
                if d < min_dist:
                    min_dist, min_pt = d, pt
        if min_pt:
            graph.setdefault(min_pt, []).append((x, 1))


def connect_slots_to_corridors(
    graph: Dict, slots: List[Dict], corridors: List[Dict]
) -> None:
    """
    Connect parking slots to the nearest corridor points

    Args:
        graph: Graph to modify
        slots: List of slot objects with x, y coordinates
        corridors: List of corridor objects
    """
    for s in slots:
        slot_pt = (s["x"], s["y"])
        min_dist, min_pt = float("inf"), None
        for corridor in corridors:
            for pt in corridor["points"]:
                d = euclidean_distance(slot_pt, pt)
                if d < min_dist:
                    min_dist, min_pt = d, pt
        if min_pt:
            graph.setdefault(slot_pt, []).append((min_pt, 1))
            graph.setdefault(min_pt, []).append((slot_pt, 1))


def is_adjacent(point1, point2):
    """
    Check if two points are adjacent (horizontally or vertically, but not diagonally)

    Args:
        point1: First point (x, y)
        point2: Second point (x, y)

    Returns:
        bool: True if points are adjacent, False otherwise
    """
    # Calculate absolute differences in x and y coordinates
    dx = abs(point1[0] - point2[0])
    dy = abs(point1[1] - point2[1])

    # Points are adjacent if they differ by 1 in exactly one coordinate
    return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)


def build_full_map_graph(map_data: List[Dict]) -> Dict:
    """
    Build a comprehensive, connected graph for the entire parking building

    Args:
        map_data: List of level data containing corridors, slots, entrances, etc.

    Returns:
        Dict: Complete graph representation for pathfinding
    """
    graph = {}
    import logging

    # 1. Build the base corridor network for all levels - strict adjacency check
    for level_data in map_data:
        level = level_data["level"]
        for corridor in level_data.get("corridors", []):
            pts = corridor["points"]
            for i in range(len(pts) - 1):
                a, b = pts[i], pts[i + 1]
                # Check adjacency to ensure valid connections
                if not is_adjacent(a, b):
                    logging.warning(
                        f"Corridor points {a} and {b} in level {level} are not adjacent. Skipping connection."
                    )
                    continue

                node_a, node_b = (level, a[0], a[1]), (level, b[0], b[1])
                # Use actual Euclidean distance as edge weight
                dist = euclidean_distance(a, b)
                if corridor["direction"] in ["forward", "both"]:
                    graph.setdefault(node_a, []).append((node_b, dist))
                if corridor["direction"] in ["backward", "both"]:
                    graph.setdefault(node_b, []).append((node_a, dist))

    # 2. Connect all fixed points to their nearest corridor
    for level_data in map_data:
        level = level_data["level"]
        corridors_on_level = level_data.get("corridors", [])
        if not corridors_on_level:
            continue

        # Store all parking slots for lookup
        all_parking_slots = {}
        for slot in level_data.get("slots", []):
            slot_key = (level, slot["x"], slot["y"])
            all_parking_slots[slot_key] = slot

        points_to_connect = []
        # Gather all points on the current level EXCEPT parking slots (we'll handle them separately)
        for entrance in level_data.get("entrances", []):
            if entrance.get("type") == "car":
                points_to_connect.append(
                    {"x": entrance["x"], "y": entrance["y"], "type": "bi-directional"}
                )
        for ramp in level_data.get("ramps", []):
            points_to_connect.append(
                {"x": ramp["x"], "y": ramp["y"], "type": "bi-directional"}
            )
        for exit_item in level_data.get("exits", []):
            points_to_connect.append(
                {"x": exit_item["x"], "y": exit_item["y"], "type": "exit"}
            )

        # First connect non-parking points
        for point in points_to_connect:
            point_node = (level, point["x"], point["y"])
            point_coord = (point["x"], point["y"])

            # Find all corridor points with minimum distance
            min_dist = float("inf")
            candidate_corridors = []

            for corridor in corridors_on_level:
                for pt in corridor["points"]:
                    # Skip if corridor point is already a slot
                    corridor_node = (level, pt[0], pt[1])
                    if corridor_node in all_parking_slots:
                        continue

                    d = euclidean_distance(point_coord, pt)
                    if d < min_dist:
                        min_dist = d
                        candidate_corridors = [(level, pt[0], pt[1])]
                    elif d == min_dist:
                        candidate_corridors.append((level, pt[0], pt[1]))

            # If we have multiple candidates with same distance, choose the optimal one
            if candidate_corridors:
                if len(candidate_corridors) == 1:
                    nearest_corridor_node = candidate_corridors[0]
                else:
                    # Prioritize corridors that are actually adjacent to the point
                    adjacent_candidates = []
                    for candidate in candidate_corridors:
                        candidate_coord = (candidate[1], candidate[2])
                        if is_adjacent(point_coord, candidate_coord):
                            adjacent_candidates.append(candidate)

                    if adjacent_candidates:
                        # Prefer corridors that are adjacent
                        nearest_corridor_node = adjacent_candidates[0]
                    else:
                        # For multiple candidates, choose the one with better alignment
                        nearest_corridor_node = candidate_corridors[
                            0
                        ]  # Default to first

                        # Check if any candidate is horizontally aligned (same y-coordinate)
                        for candidate in candidate_corridors:
                            if (
                                candidate[2] == point["y"]
                            ):  # Same y-coordinate (horizontal alignment)
                                nearest_corridor_node = candidate
                                break

                dist_to_corridor = min_dist
                if point["type"] == "bi-directional":
                    graph.setdefault(point_node, []).append(
                        (nearest_corridor_node, dist_to_corridor)
                    )
                    graph.setdefault(nearest_corridor_node, []).append(
                        (point_node, dist_to_corridor)
                    )
                elif point["type"] == "exit":  # One-way connection
                    graph.setdefault(nearest_corridor_node, []).append(
                        (point_node, dist_to_corridor)
                    )

        # Now handle parking slots separately - connect from corridor to slot (ONE-WAY only)
        # This ensures slots are only destinations, not through-paths
        for slot in level_data.get("slots", []):
            slot_node = (level, slot["x"], slot["y"])
            slot_coord = (slot["x"], slot["y"])

            # Find nearest corridor point
            min_dist = float("inf")
            nearest_corridor_node = None

            for corridor in corridors_on_level:
                for pt in corridor["points"]:
                    # Make sure this corridor point is not already in a parking slot
                    corridor_node = (level, pt[0], pt[1])
                    if corridor_node in all_parking_slots:
                        continue

                    # Only consider adjacent corridor points - parking spots must be directly reachable
                    if not is_adjacent(slot_coord, pt):
                        continue

                    d = euclidean_distance(slot_coord, pt)
                    if d < min_dist:
                        min_dist = d
                        nearest_corridor_node = corridor_node

            if nearest_corridor_node:
                # ONE-WAY connection: corridor → slot (can enter slot but not exit through it)
                graph.setdefault(nearest_corridor_node, []).append(
                    (slot_node, min_dist)
                )

                # Add slot as start node but with no connections (needed for dijkstra to recognize it)
                if slot_node not in graph:
                    graph[slot_node] = []
            else:
                logging.warning(
                    f"Could not find adjacent corridor for slot {slot['slot_id']} at {slot_coord}. Slot may be unreachable."
                )

    # 3. Connect ramps between levels - Increase weight for level transitions
    for level_data in map_data:
        for ramp in level_data.get("ramps", []):
            from_node = (ramp["level"], ramp["x"], ramp["y"])
            to_node = (ramp["to_level"], ramp["to_x"], ramp["to_y"])
            # Use higher weight to represent the cost of moving between levels
            ramp_cost = 2.0  # Increased cost for using ramps
            if ramp.get("direction", "both") == "both":
                graph.setdefault(from_node, []).append((to_node, ramp_cost))
                graph.setdefault(to_node, []).append((from_node, ramp_cost))
            # Future-proofing for one-way ramps
            elif ramp.get("direction") == "up":
                graph.setdefault(from_node, []).append((to_node, ramp_cost))
            elif ramp.get("direction") == "down":
                graph.setdefault(to_node, []).append((from_node, ramp_cost))

    return graph


def connect_node_to_graph(graph: Dict, node: Tuple, map_data: List[Dict]) -> None:
    """
    Connect a dynamic node (like a start or end point) to the existing graph

    Args:
        graph: Graph to modify
        node: Node to connect (level, x, y)
        map_data: Map data containing level information
    """
    if not node or node in graph:
        return  # No node to add or node already exists

    import logging

    # Ensure node has the correct structure (level, x, y)
    if not isinstance(node, tuple) or len(node) < 3:
        logging.error(f"Invalid node format: {node}. Expected (level, x, y) tuple")
        return

    try:
        node_level, node_x, node_y = node
        node_coord = (node_x, node_y)
    except (ValueError, TypeError):
        logging.error(f"Failed to unpack node: {node}")
        return

    # Find the level data for the node's level
    level_data = next((l for l in map_data if l["level"] == node_level), None)
    if not level_data:
        logging.error(f"No level data found for level {node_level}")
        return  # Level not found

    # Check if this node is a parking slot
    is_parking_slot = False
    for slot in level_data.get("slots", []):
        if slot["x"] == node_x and slot["y"] == node_y:
            is_parking_slot = True
            break

    # Store all parking slots for lookup
    all_parking_slots = {}
    for slot in level_data.get("slots", []):
        slot_key = (node_level, slot["x"], slot["y"])
        all_parking_slots[slot_key] = slot

    corridors_on_level = level_data.get("corridors", [])
    if not corridors_on_level:
        logging.warning(f"No corridors found on level {node_level}")
        return  # No corridors on this level to connect to

    # Find adjacent corridor points to connect to
    adjacent_corridors = []

    for corridor in corridors_on_level:
        for pt in corridor["points"]:
            try:
                # Make sure corridor point is not a parking slot
                corridor_node = (node_level, pt[0], pt[1])
                if corridor_node in all_parking_slots:
                    continue

                # Only consider corridor points that are strictly adjacent to our node
                if is_adjacent(node_coord, pt):
                    adjacent_corridors.append(corridor_node)
            except (TypeError, IndexError):
                continue

    if adjacent_corridors:
        # Connect to all adjacent corridor points
        for corridor_node in adjacent_corridors:
            try:
                dist = euclidean_distance(
                    node_coord, (corridor_node[1], corridor_node[2])
                )

                if is_parking_slot:
                    # If node is a parking slot:
                    # 1. ONE-WAY connection: corridor → slot (can enter slot but not exit through it)
                    graph.setdefault(corridor_node, []).append((node, dist))
                    # 2. Add slot as node with no outgoing connections
                    if node not in graph:
                        graph[node] = []
                else:
                    # For non-parking nodes, create bi-directional connection
                    graph.setdefault(node, []).append((corridor_node, dist))
                    graph.setdefault(corridor_node, []).append((node, dist))
            except (TypeError, IndexError):
                logging.error(f"Failed to connect nodes: {node} and {corridor_node}")
                pass
    else:
        # Fallback: if no adjacent corridors found, find the nearest one
        logging.warning(
            f"No adjacent corridors found for node {node}. Falling back to nearest corridor."
        )
        min_dist, nearest_corridor_node = float("inf"), None

        for corridor in corridors_on_level:
            for pt in corridor["points"]:
                try:
                    # Skip parking slots
                    corridor_node = (node_level, pt[0], pt[1])
                    if corridor_node in all_parking_slots:
                        continue

                    d = euclidean_distance(node_coord, pt)
                    if d < min_dist:
                        min_dist = d
                        nearest_corridor_node = corridor_node
                except (TypeError, IndexError):
                    continue

        if nearest_corridor_node:
            try:
                dist = euclidean_distance(
                    node_coord, (nearest_corridor_node[1], nearest_corridor_node[2])
                )

                if is_parking_slot:
                    # If node is a parking slot - one way connection
                    graph.setdefault(nearest_corridor_node, []).append((node, dist))
                    if node not in graph:
                        graph[node] = []
                else:
                    # For non-parking nodes, create bi-directional connection
                    graph.setdefault(node, []).append((nearest_corridor_node, dist))
                    graph.setdefault(nearest_corridor_node, []).append((node, dist))

                logging.info(
                    f"Connected node {node} to nearest corridor {nearest_corridor_node} with distance {dist}"
                )
            except (TypeError, IndexError):
                logging.error(
                    f"Failed to connect nodes: {node} and {nearest_corridor_node}"
                )
                pass
