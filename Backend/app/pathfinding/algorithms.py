"""
Pathfinding algorithms for parking lot navigation

This module contains the core algorithms used for finding optimal paths
in parking lots, including Dijkstra's algorithm and distance calculations.
"""

import math
import heapq
from typing import Tuple, List, Optional, Dict, Any


def euclidean_distance(a: Tuple[float, float], b: Tuple[float, float]) -> float:
    """
    Calculate the Euclidean distance between two points

    Args:
        a: First point (x, y)
        b: Second point (x, y)

    Returns:
        float: Euclidean distance between the points
    """
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2)


def dijkstra(graph: Dict, start: Tuple, end: Tuple) -> Tuple[Optional[List], float]:
    """
    Implementation of Dijkstra's shortest path algorithm for parking lot navigation.
    
    This algorithm finds the optimal path between two points in a weighted graph,
    considering both distance and directional preferences for smoother navigation.
    
    Time Complexity: O((V + E) * log V) where V = vertices, E = edges
    Space Complexity: O(V) for the priority queue and visited set
    
    Algorithm Steps:
    1. Initialize priority queue with start node (cost=0)
    2. Mark all nodes as unvisited
    3. For current node, examine unvisited neighbors
    4. Calculate tentative distances through current node
    5. Update neighbor distances if shorter path found
    6. Mark current node as visited
    7. Select unvisited node with smallest distance as new current node
    8. Repeat until destination reached or all reachable nodes visited
    
    Optimizations:
    - Direction-aware path selection for straighter routes
    - Early termination when destination is reached
    - Efficient heap-based priority queue implementation

    Args:
        graph (Dict): Graph representation as adjacency list with edge weights
                     Format: {node: [(neighbor1, weight1), (neighbor2, weight2), ...]}
                     where nodes are tuples (level, x, y)
        start (Tuple): Starting coordinate (level, x, y)
        end (Tuple): Destination coordinate (level, x, y)

    Returns:
        Tuple[Optional[List], float]: 
            - path: Ordered list of coordinates from start to end, or None if unreachable
            - total_distance: Cumulative distance along optimal path, or infinity if unreachable
            
    Example:
        >>> graph = {
        ...     (1, 0, 0): [((1, 1, 0), 1.0), ((1, 0, 1), 1.0)],
        ...     (1, 1, 0): [((1, 2, 0), 1.0)],
        ...     (1, 0, 1): [((1, 1, 1), 1.4)],
        ...     (1, 2, 0): [],  # Destination parking slot
        ... }
        >>> path, distance = dijkstra(graph, (1, 0, 0), (1, 2, 0))
        >>> print(f"Path: {path}, Distance: {distance}")
        Path: [(1, 0, 0), (1, 1, 0), (1, 2, 0)], Distance: 2.0
    """
    # Check if start and end nodes are in the graph
    if start not in graph:
        import logging

        logging.error(f"Start node {start} not in graph")
        return None, float("inf")

    if end not in graph:
        import logging

        logging.error(f"End node {end} not in graph")
        return None, float("inf")

    # If end node has no connections but start node does, it's likely a valid path
    # For example, when end node is a parking slot (which has no outgoing connections)
    if not graph[end] and start != end:
        import logging

        logging.info(
            f"End node {end} has no outgoing connections. Checking if it can be reached."
        )

    # Initialize data structures for Dijkstra's algorithm
    # Priority queue: (cumulative_cost, current_node, path_so_far)
    heap = [(0, start, [])]
    # Set to track visited nodes to avoid cycles
    visited = set()

    # Main algorithm loop - process nodes in order of increasing distance
    while heap:
        # Extract minimum cost node from priority queue
        (cost, node, path) = heapq.heappop(heap)
        
        # Skip if already processed (can happen with priority queue)
        if node in visited:
            continue

        # Build path by appending current node
        path = path + [node]
        
        # Check if we've reached the destination
        if node == end:
            return path, cost

        # Mark current node as visited
        visited.add(node)
        # Get neighbors of current node from adjacency list
        neighbors = graph.get(node, [])

        # OPTIMIZATION: Sort neighbor nodes to prioritize straighter paths
        # This heuristic improves path quality by reducing unnecessary turns
        # while maintaining optimality of Dijkstra's algorithm
        if len(path) >= 2:
            prev_node = path[-2]

            # Ensure nodes have the expected structure (level, x, y)
            if (
                isinstance(node, tuple)
                and len(node) >= 3
                and isinstance(prev_node, tuple)
                and len(prev_node) >= 3
            ):
                try:
                    current_direction = (
                        node[1] - prev_node[1],  # dx
                        node[2] - prev_node[2],  # dy
                    )

                    # Sort neighbors based on continuity with current direction
                    def direction_score(neighbor):
                        if (
                            not isinstance(neighbor, tuple)
                            or not isinstance(neighbor[0], tuple)
                            or len(neighbor[0]) < 3
                        ):
                            return 0

                        try:
                            next_direction = (
                                neighbor[0][1] - node[1],  # dx to next
                                neighbor[0][2] - node[2],  # dy to next
                            )

                            # Calculate degree of direction change (dot product)
                            if current_direction[0] == 0 and current_direction[1] == 0:
                                return 0

                            magnitude1 = (
                                current_direction[0] ** 2 + current_direction[1] ** 2
                            ) ** 0.5
                            magnitude2 = (
                                next_direction[0] ** 2 + next_direction[1] ** 2
                            ) ** 0.5

                            if magnitude1 == 0 or magnitude2 == 0:
                                return 0

                            dot_product = (
                                current_direction[0] * next_direction[0]
                                + current_direction[1] * next_direction[1]
                            )
                            direction_similarity = dot_product / (
                                magnitude1 * magnitude2
                            )

                            # Closer to 1 indicates more similar direction (straight ahead)
                            return direction_similarity
                        except (IndexError, TypeError):
                            return 0

                    # Sort neighbors by direction similarity
                    try:
                        sorted_neighbors = sorted(
                            neighbors, key=direction_score, reverse=True
                        )
                    except Exception:
                        sorted_neighbors = neighbors
                except (IndexError, TypeError):
                    sorted_neighbors = neighbors
            else:
                sorted_neighbors = neighbors
        else:
            sorted_neighbors = neighbors

        # Process all neighbor nodes
        for neighbor, weight in sorted_neighbors:
            # Skip if already visited
            if neighbor in visited:
                continue

            # Special handling for parking slots
            # If neighbor is a parking slot with no outgoing connections AND it's not our destination
            # Don't go through it (we don't want to use parking slots as through-paths)
            if neighbor != end and not graph.get(neighbor, []):
                import logging

                logging.debug(
                    f"Skipping node {neighbor} as it appears to be a parking slot with no exits"
                )
                continue

            # Calculate turn penalty
            turn_penalty = 0
            if len(path) >= 2:
                prev_node = path[-2]

                # Ensure nodes have the expected structure
                if (
                    isinstance(prev_node, tuple)
                    and len(prev_node) >= 3
                    and isinstance(node, tuple)
                    and len(node) >= 3
                    and isinstance(neighbor, tuple)
                    and len(neighbor) >= 3
                ):
                    try:
                        # Detect if direction has changed
                        is_straight_x = prev_node[1] == node[1] == neighbor[1]
                        is_straight_y = prev_node[2] == node[2] == neighbor[2]

                        # If neither straight in x nor y direction, there's a turn
                        if not (is_straight_x or is_straight_y):
                            turn_penalty = (
                                0.1  # Small penalty to favor straighter paths
                            )
                    except (IndexError, TypeError):
                        pass

            # Add neighbor to priority queue with weight plus turn penalty
            heapq.heappush(heap, (cost + weight + turn_penalty, neighbor, path))

    return None, float("inf")


def manhattan_distance(a: Tuple[float, float], b: Tuple[float, float]) -> float:
    """
    Calculate the Manhattan distance between two points

    Args:
        a: First point (x, y)
        b: Second point (x, y)

    Returns:
        float: Manhattan distance between the points
    """
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def find_nearest_point(
    target: Tuple[float, float],
    points: List[Tuple[float, float]],
    distance_func=euclidean_distance,
) -> Tuple[Tuple[float, float], float]:
    """
    Find the nearest point from a list of points to a target point

    Args:
        target: Target point (x, y)
        points: List of candidate points
        distance_func: Distance function to use (default: euclidean_distance)

    Returns:
        Tuple[Tuple[float, float], float]: (nearest_point, distance)
    """
    if not points:
        return None, float("inf")

    min_distance = float("inf")
    nearest_point = None

    for point in points:
        distance = distance_func(target, point)
        if distance < min_distance:
            min_distance = distance
            nearest_point = point

    return nearest_point, min_distance
