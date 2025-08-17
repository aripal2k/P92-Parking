"""
Nearest point finder for parking lot navigation

This module contains functions for finding the nearest parking slots
and other points of interest in parking lots.
"""

from typing import Dict, List, Tuple, Optional, Any
from .algorithms import euclidean_distance, find_nearest_point


def find_nearest_exit(
    target_point: Tuple[float, float], exits: List[Dict], level: Optional[int] = None
) -> Tuple[Optional[Dict], float]:
    """
    Find the nearest exit to a target point (or slot)
    """
    if not exits:
        return None, float("inf")

    # Filter exits by level if specified
    filtered_exits = exits
    if level is not None:
        filtered_exits = [e for e in filtered_exits if e.get("level") == level]

    if not filtered_exits:
        return None, float("inf")

    # Find nearest exit
    min_distance = float("inf")
    nearest_exit = None

    for exit in filtered_exits:
        exit_point = (exit["x"], exit["y"])
        distance = euclidean_distance(target_point, exit_point)
        if distance < min_distance:
            min_distance = distance
            nearest_exit = exit

    return nearest_exit, min_distance


def find_nearest_slot(
    target_point: Tuple[float, float],
    slots: List[Dict],
    level: Optional[int] = None,
    status_filter: Optional[str] = None,
) -> Tuple[Optional[Dict], float]:
    """
    Find the nearest parking slot to a target point

    Args:
        target_point: Target point (x, y)
        slots: List of slot objects with x, y coordinates and status
        level: Optional level filter
        status_filter: Optional status filter (e.g., "available", "occupied")

    Returns:
        Tuple[Optional[Dict], float]: (nearest_slot, distance)
    """
    if not slots:
        return None, float("inf")

    # Filter slots by level and status if specified
    filtered_slots = slots
    if level is not None:
        filtered_slots = [s for s in filtered_slots if s.get("level") == level]
    if status_filter is not None:
        filtered_slots = [s for s in filtered_slots if s.get("status") == status_filter]

    if not filtered_slots:
        return None, float("inf")

    # Find nearest slot
    min_distance = float("inf")
    nearest_slot = None

    for slot in filtered_slots:
        slot_point = (slot["x"], slot["y"])
        distance = euclidean_distance(target_point, slot_point)
        if distance < min_distance:
            min_distance = distance
            nearest_slot = slot

    return nearest_slot, min_distance


def find_nearest_entrance(
    target_point: Tuple[float, float],
    entrances: List[Dict],
    level: Optional[int] = None,
) -> Tuple[Optional[Dict], float]:
    """
    Find the nearest entrance to a target point

    Args:
        target_point: Target point (x, y)
        entrances: List of entrance objects
        level: Optional level filter

    Returns:
        Tuple[Optional[Dict], float]: (nearest_entrance, distance)
    """
    if not entrances:
        return None, float("inf")

    # Filter entrances by level if specified
    filtered_entrances = entrances
    if level is not None:
        filtered_entrances = [e for e in entrances if e.get("level") == level]

    if not filtered_entrances:
        return None, float("inf")

    # Find nearest entrance
    min_distance = float("inf")
    nearest_entrance = None

    for entrance in filtered_entrances:
        entrance_point = (entrance["x"], entrance["y"])
        distance = euclidean_distance(target_point, entrance_point)
        if distance < min_distance:
            min_distance = distance
            nearest_entrance = entrance

    return nearest_entrance, min_distance


def find_nearest_ramp(
    target_point: Tuple[float, float], ramps: List[Dict], level: Optional[int] = None
) -> Tuple[Optional[Dict], float]:
    """
    Find the nearest ramp to a target point

    Args:
        target_point: Target point (x, y)
        ramps: List of ramp objects
        level: Optional level filter

    Returns:
        Tuple[Optional[Dict], float]: (nearest_ramp, distance)
    """
    if not ramps:
        return None, float("inf")

    # Filter ramps by level if specified
    filtered_ramps = ramps
    if level is not None:
        filtered_ramps = [r for r in ramps if r.get("level") == level]

    if not filtered_ramps:
        return None, float("inf")

    # Find nearest ramp
    min_distance = float("inf")
    nearest_ramp = None

    for ramp in filtered_ramps:
        ramp_point = (ramp["x"], ramp["y"])
        distance = euclidean_distance(target_point, ramp_point)
        if distance < min_distance:
            min_distance = distance
            nearest_ramp = ramp

    return nearest_ramp, min_distance


def find_nearest_point_by_type(
    target_point: Tuple[float, float],
    map_data: List[Dict],
    point_type: str,
    level: Optional[int] = None,
) -> Tuple[Optional[Dict], float]:
    """
    Find the nearest point of a specific type to a target point

    Args:
        target_point: Target point (x, y)
        map_data: Map data containing all levels
        point_type: Type of point to find ("entrance", "exit", "ramp", "slot")
        level: Optional level filter

    Returns:
        Tuple[Optional[Dict], float]: (nearest_point, distance)
    """
    all_points = []

    # Collect all points of the specified type
    for level_data in map_data:
        if level is not None and level_data.get("level") != level:
            continue

        if point_type == "entrance":
            points = level_data.get("entrances", [])
        elif point_type == "exit":
            points = level_data.get("exits", [])
        elif point_type == "ramp":
            points = level_data.get("ramps", [])
        elif point_type == "slot":
            points = level_data.get("slots", [])
        else:
            continue

        all_points.extend(points)

    if not all_points:
        return None, float("inf")

    # Find nearest point
    min_distance = float("inf")
    nearest_point = None

    for point in all_points:
        point_coord = (point["x"], point["y"])
        distance = euclidean_distance(target_point, point_coord)
        if distance < min_distance:
            min_distance = distance
            nearest_point = point

    return nearest_point, min_distance


def find_nearest_available_slot_to_point(
    target_point: Tuple[float, float], map_data: List[Dict], level: Optional[int] = None
) -> Tuple[Optional[Dict], float]:
    """
    Find the nearest available parking slot to a target point

    Args:
        target_point: Target point (x, y)
        map_data: Map data containing all levels
        level: Optional level filter

    Returns:
        Tuple[Optional[Dict], float]: (nearest_slot, distance)
    """
    all_slots = []

    # Collect all available slots
    for level_data in map_data:
        if level is not None and level_data.get("level") != level:
            continue

        slots = level_data.get("slots", [])
        available_slots = [s for s in slots if s.get("status") in ["available", "free"]]
        all_slots.extend(available_slots)

    if not all_slots:
        return None, float("inf")

    # Find nearest available slot
    return find_nearest_slot(target_point, all_slots)
