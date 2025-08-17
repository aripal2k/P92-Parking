"""
Path planner for parking lot navigation

This module provides a high-level interface for planning paths
in parking lots, including finding nearest slots and optimal routes.
"""

from typing import Dict, List, Tuple, Optional, Any
from .algorithms import dijkstra, euclidean_distance
from .graph_builder import build_full_map_graph, connect_node_to_graph
from .nearest_finder import (
    find_nearest_slot,
    find_nearest_entrance,
    find_nearest_ramp,
    find_nearest_point_by_type,
    find_nearest_available_slot_to_point,
    find_nearest_exit,
)


class PathPlanner:
    """
    High-level path planner for parking lot navigation

    This class provides methods for finding optimal paths between points
    in parking lots, including finding nearest parking slots and planning routes.
    """

    def __init__(self, map_data: List[Dict]):
        """
        Initialize the path planner with map data

        Args:
            map_data: List of level data containing parking lot information
        """
        self.map_data = map_data
        self.graph = build_full_map_graph(map_data)

    def find_nearest_slot_to_point(
        self,
        target_point: Tuple[float, float],
        level: Optional[int] = None,
        status_filter: str = "available",
    ) -> Tuple[Optional[Dict], float]:
        """
        Find the nearest parking slot to a target point

        Args:
            target_point: Target point (x, y)
            level: Optional level filter
            status_filter: Status filter for slots (default: "available")

        Returns:
            Tuple[Optional[Dict], float]: (nearest_slot, distance)
        """
        all_slots = []
        for level_data in self.map_data:
            if level is not None and level_data.get("level") != level:
                continue
            slots = level_data.get("slots", [])
            if status_filter:
                slots = [s for s in slots if s.get("status") == status_filter]
            all_slots.extend(slots)

        return find_nearest_slot(target_point, all_slots)

    def find_nearest_slot_to_entrance(
        self, entrance_id: str, level: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Find the nearest available parking slot to a specific entrance

        Args:
            entrance_id: ID of the entrance
            level: Optional level filter

        Returns:
            Dict containing nearest slot info and path details
        """
        # Find the entrance
        entrance = None
        for level_data in self.map_data:
            if level is not None and level_data.get("level") != level:
                continue
            for e in level_data.get("entrances", []):
                if e.get("entrance_id") == entrance_id:
                    entrance = e
                    break
            if entrance:
                break

        if not entrance:
            return {"error": f"Entrance '{entrance_id}' not found"}

        # Find nearest available slot
        entrance_point = (entrance["x"], entrance["y"])
        nearest_slot, direct_distance = self.find_nearest_slot_to_point(
            entrance_point, level
        )

        if not nearest_slot:
            return {"error": "No available parking slots found"}

        # Calculate path from entrance to slot
        start_point = (entrance.get("level", 1), entrance["x"], entrance["y"])
        end_point = (nearest_slot.get("level", 1), nearest_slot["x"], nearest_slot["y"])

        path, path_distance = self.find_path(start_point, end_point)

        return {
            "entrance": entrance,
            "nearest_slot": nearest_slot,
            "direct_distance": direct_distance,
            "path": path,
            "path_distance": path_distance,
            "path_points": len(path) if path else 0,
        }

    def find_nearest_slot_to_ramp(
        self, ramp_id: str, level: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Find the nearest available parking slot to a specific ramp

        Args:
            ramp_id: ID of the ramp
            level: Optional level filter

        Returns:
            Dict containing nearest slot info and path details
        """
        # Find the ramp
        ramp = None
        for level_data in self.map_data:
            if level is not None and level_data.get("level") != level:
                continue
            for r in level_data.get("ramps", []):
                if r.get("ramp_id") == ramp_id:
                    ramp = r
                    break
            if ramp:
                break

        if not ramp:
            return {"error": f"Ramp '{ramp_id}' not found"}

        # Find nearest available slot
        ramp_point = (ramp["x"], ramp["y"])
        nearest_slot, direct_distance = self.find_nearest_slot_to_point(
            ramp_point, level
        )

        if not nearest_slot:
            return {"error": "No available parking slots found"}

        # Calculate path from ramp to slot
        start_point = (ramp.get("level", 1), ramp["x"], ramp["y"])
        end_point = (nearest_slot.get("level", 1), nearest_slot["x"], nearest_slot["y"])

        path, path_distance = self.find_path(start_point, end_point)

        return {
            "ramp": ramp,
            "nearest_slot": nearest_slot,
            "direct_distance": direct_distance,
            "path": path,
            "path_distance": path_distance,
            "path_points": len(path) if path else 0,
        }

    def find_nearest_slot_to_point_type(
        self, point_type: str, point_id: str, level: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Find the nearest available parking slot to a point of specific type

        Args:
            point_type: Type of point ("entrance", "exit", "ramp")
            point_id: ID of the point
            level: Optional level filter

        Returns:
            Dict containing nearest slot info and path details
        """
        # Find the point
        point = None
        for level_data in self.map_data:
            if level is not None and level_data.get("level") != level:
                continue

            points = []
            if point_type == "entrance":
                points = level_data.get("entrances", [])
            elif point_type == "exit":
                points = level_data.get("exits", [])
            elif point_type == "ramp":
                points = level_data.get("ramps", [])

            for p in points:
                if p.get(f"{point_type}_id") == point_id:
                    point = p
                    break
            if point:
                break

        if not point:
            return {"error": f"{point_type.capitalize()} '{point_id}' not found"}

        # Find nearest available slot
        point_coord = (point["x"], point["y"])
        nearest_slot, direct_distance = self.find_nearest_slot_to_point(
            point_coord, level
        )

        if not nearest_slot:
            return {"error": "No available parking slots found"}

        # Calculate path from point to slot
        start_point = (point.get("level", 1), point["x"], point["y"])
        end_point = (nearest_slot.get("level", 1), nearest_slot["x"], nearest_slot["y"])

        path, path_distance = self.find_path(start_point, end_point)

        return {
            "source_point": {"type": point_type, "id": point_id, "data": point},
            "nearest_slot": nearest_slot,
            "direct_distance": direct_distance,
            "path": path,
            "path_distance": path_distance,
            "path_points": len(path) if path else 0,
        }

    def find_path(self, start: Tuple, end: Tuple) -> Tuple[Optional[List], float]:
        """
        Find the shortest path between two points

        Args:
            start: Starting point (level, x, y)
            end: Ending point (level, x, y)

        Returns:
            Tuple[Optional[List], float]: (path, distance)
        """
        # Connect start and end points to the graph
        connect_node_to_graph(self.graph, start, self.map_data)
        connect_node_to_graph(self.graph, end, self.map_data)

        # Find shortest path
        return dijkstra(self.graph, start, end)

    def get_all_entrances(self) -> List[Dict]:
        """Get all entrances from the map data"""
        entrances = []
        for level_data in self.map_data:
            entrances.extend(level_data.get("entrances", []))
        return entrances

    def get_all_ramps(self) -> List[Dict]:
        """Get all ramps from the map data"""
        ramps = []
        for level_data in self.map_data:
            ramps.extend(level_data.get("ramps", []))
        return ramps

    def get_available_slots(self, level: Optional[int] = None) -> List[Dict]:
        """Get all available parking slots"""
        slots = []
        for level_data in self.map_data:
            if level is not None and level_data.get("level") != level:
                continue
            available_slots = [
                s
                for s in level_data.get("slots", [])
                if s.get("status") in ["available", "free"]
            ]
            slots.extend(available_slots)
        return slots

    def find_nearest_exit_to_slot(
        self, slot_id: str
    ) -> Tuple[Optional[Dict], Optional[float], Optional[List]]:
        """
        Find the nearest exit to a parking slot and calculate the path
        """
        # Find the parking slot
        target_slot = None
        slot_level = None
        for level_data in self.map_data:
            for slot in level_data.get("slots", []):
                if slot.get("slot_id") == slot_id:
                    target_slot = slot
                    slot_level = level_data.get("level", 1)
                    break
            if target_slot:
                break

        if not target_slot:
            return None, None, None

        # Get slot coordinates
        slot_point = (target_slot["x"], target_slot["y"])
        slot_coords = (slot_level, target_slot["x"], target_slot["y"])

        # Collect all exits from all levels
        all_exits = []
        for level_data in self.map_data:
            level_num = level_data.get("level", 1)
            for exit in level_data.get("exits", []):
                exit_with_level = exit.copy()
                exit_with_level["level"] = level_num
                all_exits.append(exit_with_level)

        if not all_exits:
            return None, None, None

        # Find nearest exit by actual pathfinding distance
        nearest_exit = None
        shortest_distance = float("inf")
        shortest_path = None

        # Enable slot to be used as starting point for pathfinding
        def enable_slot_exit(graph, slot_node):
            """Temporarily add bidirectional connection for a parking slot"""
            for node, connections in graph.items():
                for connected_node, distance in connections:
                    if connected_node == slot_node:
                        if slot_node not in graph:
                            graph[slot_node] = []
                        if not any(conn[0] == node for conn in graph[slot_node]):
                            graph[slot_node].append((node, distance))

        enable_slot_exit(self.graph, slot_coords)

        # Test each exit to find the nearest one by pathfinding distance
        for exit in all_exits:
            exit_coords = (exit["level"], exit["x"], exit["y"])

            try:
                path, distance = self.find_path(slot_coords, exit_coords)
                if path and distance < shortest_distance:
                    shortest_distance = distance
                    nearest_exit = exit
                    shortest_path = path
            except:
                # If pathfinding fails for this exit, skip it
                continue

        if nearest_exit and shortest_path:
            return nearest_exit, shortest_distance, shortest_path
        else:
            return None, None, None
