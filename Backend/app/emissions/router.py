"""
Carbon Emissions Estimation API Router

API endpoints for calculating carbon emissions
saved by using efficient parking routes.
"""

from fastapi import APIRouter, Query, HTTPException
from typing import Optional, Dict, Any, List
import logging
from app.parking.utils import get_map_data
from app.pathfinding.path_planner import PathPlanner
from app.emissions.calculator import (
    calculate_emissions_saved,
    calculate_dynamic_baseline,
    format_emissions_message,
)
from app.emissions.storage import emission_storage
from app.emissions.models import EmissionHistoryQuery
from app.database import session_collection

router = APIRouter(prefix="/emissions", tags=["carbon-emissions"])


@router.get(
    "/estimate",
    responses={
        200: {
            "description": "Calculate carbon emissions saved for a given route distance",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "route_distance": 25.5,
                        "baseline_distance": 85.2,
                        "emissions_factor": 0.194,
                        "actual_emissions": 4.90,
                        "baseline_emissions": 16.36,
                        "emissions_saved": 11.46,
                        "percentage_saved": 70.1,
                        "message": "You saved 11.5g CO₂ (70.1%) by using AutoSpot!",
                        "calculation_method": "static",
                    }
                }
            },
        },
        400: {
            "description": "Invalid parameters",
            "content": {
                "application/json": {
                    "example": {"detail": "Route distance must be positive"}
                }
            },
        },
    },
)
def estimate_emissions(
    route_distance: float = Query(
        ..., description="Distance of the route in meters", gt=0
    ),
    baseline_distance: Optional[float] = Query(
        None,
        description="Baseline search distance in meters. If not provided, uses default.",
        gt=0,
    ),
    emissions_factor: Optional[float] = Query(
        None,
        description="CO2 emissions factor in grams per meter. If not provided, uses default.",
        gt=0,
    ),
    username: Optional[str] = Query(
        None, description="Username for storing emission history"
    ),
    session_id: Optional[str] = Query(
        None, description="Session ID for associating with parking session"
    ),
):
    """
    Estimate carbon emissions saved by using efficient routing

    This feature calculates how much CO₂ emissions are saved by using Autospot's shortest path
    routing instead of searching randomly for parking spots.

    **Parameters:**
    - **route_distance**: The actual distance traveled using shortest path (meters)
    - **baseline_distance**: (optional) Distance that would be traveled without guidance (meters)
    - **emissions_factor**: (optional) CO₂ emissions per meter (grams/meter)

    """
    try:
        # Calculate emissions using provided/default values
        emissions_data = calculate_emissions_saved(
            actual_distance=route_distance,
            baseline_distance=baseline_distance,
            emissions_factor=emissions_factor,
        )

        # Add formatted message
        emissions_data["message"] = format_emissions_message(emissions_data)

        # Add metadata
        emissions_data["success"] = True
        emissions_data["calculation_method"] = "static"

        # Store emission data automatically
        try:
            record_id = emission_storage.store_emission_record(
                route_distance=emissions_data["actual_distance"],
                baseline_distance=emissions_data["baseline_distance"],
                emissions_factor=emissions_data["emissions_factor"],
                actual_emissions=emissions_data["actual_emissions"],
                baseline_emissions=emissions_data["baseline_emissions"],
                emissions_saved=emissions_data["emissions_saved"],
                percentage_saved=emissions_data["percentage_saved"],
                calculation_method="static",
                endpoint_used="/emissions/estimate",
                username=username,
                session_id=session_id,
            )
            if record_id:
                emissions_data["record_id"] = record_id
        except Exception as e:
            logging.warning(f"Failed to store emission data: {e}")

        return emissions_data

    except Exception as e:
        logging.error(f"Error calculating emissions: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to calculate emissions: {str(e)}"
        )


@router.get(
    "/estimate-for-route",
    responses={
        200: {
            "description": "Calculate emissions saved for a specific route in a parking map",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "route_distance": 18.5,
                        "baseline_distance": 67.3,
                        "emissions_saved": 9.37,
                        "percentage_saved": 72.5,
                        "message": "You saved 9.4g CO₂ (72.5%) by using AutoSpot!",
                        "calculation_method": "dynamic",
                        "map_info": {
                            "building_name": "Westfield Sydney",
                            "map_id": "999999",
                        },
                    }
                }
            },
        },
        404: {"description": "Map not found"},
    },
)
def estimate_emissions_for_route(
    start: str = Query(
        ..., description="Start point in 'level,x,y' format", example="1,0,3"
    ),
    end: str = Query(
        ..., description="End point in 'level,x,y' format", example="1,5,5"
    ),
    building_name: Optional[str] = Query(None, description="Building name"),
    map_id: Optional[str] = Query(None, description="Map ID"),
    use_dynamic_baseline: bool = Query(
        True, description="Whether to calculate baseline based on parking lot size"
    ),
    username: Optional[str] = Query(
        None, description="Username for storing emission history"
    ),
    session_id: Optional[str] = Query(
        None, description="Session ID for associating with parking session"
    ),
):
    """
    Calculate emissions saved for a specific route in a parking map

    This endpoint calculates the shortest path between two points and estimates
    the carbon emissions saved compared to searching without guidance.

    **Parameters:**
    - **start**: Starting coordinate in format "level,x,y" (e.g., "1,0,3")
    - **end**: Ending coordinate in format "level,x,y" (e.g., "1,5,5")
    - **building_name**: (optional) Building name to search for
    - **map_id**: (optional) Map ID to search for
    - **use_dynamic_baseline**: Whether to calculate baseline based on parking lot characteristics

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
        # uses path planner in pathfinding to get the shortest path between the start and end points
        # route_distance is the total length of the shortest path found by our pathfinding algorithm(Dijkstra's alg)
        path, route_distance = planner.find_path(start_pt, end_pt)

        if not path:
            raise HTTPException(
                status_code=404, detail="No path found between the specified points."
            )

        # Calculate emissions
        start_coords = (start_pt[1], start_pt[2])  # (x, y) from (level, x, y)

        if use_dynamic_baseline:
            baseline_distance = calculate_dynamic_baseline(parking_map, start_coords)
            calculation_method = "dynamic"
        else:
            baseline_distance = None
            calculation_method = "static"

        emissions_data = calculate_emissions_saved(
            actual_distance=route_distance,  # total length of shortest path using DIjkstra's
            baseline_distance=baseline_distance,
        )

        # Add formatted message and metadata
        emissions_data["message"] = format_emissions_message(emissions_data)
        emissions_data["success"] = True
        emissions_data["calculation_method"] = calculation_method
        emissions_data["map_info"] = {
            "building_name": map_data.get("building_name"),
            "map_id": str(map_data.get("_id", "")),
        }

        # Store emission data automatically
        try:
            record_id = emission_storage.store_emission_record(
                route_distance=emissions_data["actual_distance"],
                baseline_distance=emissions_data["baseline_distance"],
                emissions_factor=emissions_data["emissions_factor"],
                actual_emissions=emissions_data["actual_emissions"],
                baseline_emissions=emissions_data["baseline_emissions"],
                emissions_saved=emissions_data["emissions_saved"],
                percentage_saved=emissions_data["percentage_saved"],
                calculation_method=calculation_method,
                endpoint_used="/emissions/estimate-for-route",
                username=username,
                session_id=session_id,
                map_info=emissions_data["map_info"],
            )
            if record_id:
                emissions_data["record_id"] = record_id
        except Exception as e:
            logging.warning(f"Failed to store emission data: {e}")

        return emissions_data

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error calculating route emissions: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to calculate route emissions: {str(e)}"
        )


@router.get(
    "/estimate-for-parking-search",
    responses={
        200: {
            "description": "Calculate emissions saved when finding parking from entrance to nearest slot",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "entrance": {"entrance_id": "E1", "x": 0, "y": 3, "level": 1},
                        "nearest_slot": {"slot_id": "1A", "x": 8, "y": 3, "level": 1},
                        "route_distance": 8.0,
                        "emissions_saved": 12.5,
                        "percentage_saved": 81.2,
                        "message": "You saved 12.5g CO₂ (81.2%) by using AutoSpot!",
                        "calculation_method": "dynamic",
                    }
                }
            },
        },
        404: {"description": "Entrance or map not found"},
    },
)
def estimate_emissions_for_parking_search(
    entrance_id: str = Query(
        ..., description="Entrance ID where user enters", example="E1"
    ),
    building_name: Optional[str] = Query(None, description="Building name"),
    map_id: Optional[str] = Query(None, description="Map ID"),
    use_dynamic_baseline: bool = Query(
        True, description="Whether to calculate baseline based on parking lot size"
    ),
    username: Optional[str] = Query(
        None, description="Username for storing emission history"
    ),
    session_id: Optional[str] = Query(
        None, description="Session ID for associating with parking session"
    ),
):
    """
    Calculate emissions saved when finding parking from entrance

    This endpoint finds the nearest available parking slot from a specified entrance
    and calculates the carbon emissions saved compared to searching without guidance.

    **Parameters:**
    - **entrance_id**: ID of the entrance (e.g., "E1", "BE2")
    - **building_name**: (optional) Building name to search for
    - **map_id**: (optional) Map ID to search for
    - **use_dynamic_baseline**: Whether to calculate baseline based on parking lot characteristics
    """
    try:
        # Get map data
        map_data = get_map_data(map_id, building_name)
        if not map_data:
            raise HTTPException(status_code=404, detail="Map not found")

        parking_map = map_data.get("parking_map", [])
        if not parking_map:
            raise HTTPException(status_code=404, detail="No parking map data found")

        # Create path planner
        planner = PathPlanner(parking_map)

        # Find nearest slot to entrance
        result = planner.find_nearest_slot_to_entrance(entrance_id)

        if "error" in result:
            raise HTTPException(status_code=404, detail=result["error"])

        route_distance = result.get("path_distance", 0)
        entrance = result.get("entrance")
        nearest_slot = result.get("nearest_slot")

        if not entrance:
            raise HTTPException(
                status_code=404, detail=f"Entrance '{entrance_id}' not found"
            )

        # Calculate emissions
        entrance_coords = (entrance["x"], entrance["y"])

        if use_dynamic_baseline:
            baseline_distance = calculate_dynamic_baseline(parking_map, entrance_coords)
            calculation_method = "dynamic"
        else:
            baseline_distance = None
            calculation_method = "static"

        emissions_data = calculate_emissions_saved(
            actual_distance=route_distance, baseline_distance=baseline_distance
        )

        # Add formatted message and metadata
        emissions_data["message"] = format_emissions_message(emissions_data)
        emissions_data["success"] = True
        emissions_data["calculation_method"] = calculation_method
        emissions_data["entrance"] = entrance
        emissions_data["nearest_slot"] = nearest_slot

        # Store emission data automatically
        try:
            record_id = emission_storage.store_emission_record(
                route_distance=emissions_data["actual_distance"],
                baseline_distance=emissions_data["baseline_distance"],
                emissions_factor=emissions_data["emissions_factor"],
                actual_emissions=emissions_data["actual_emissions"],
                baseline_emissions=emissions_data["baseline_emissions"],
                emissions_saved=emissions_data["emissions_saved"],
                percentage_saved=emissions_data["percentage_saved"],
                calculation_method=calculation_method,
                endpoint_used="/emissions/estimate-for-parking-search",
                username=username,
                session_id=session_id,
                journey_details={
                    "entrance": emissions_data["entrance"],
                    "nearest_slot": emissions_data["nearest_slot"],
                },
            )
            if record_id:
                emissions_data["record_id"] = record_id
        except Exception as e:
            logging.warning(f"Failed to store emission data: {e}")
            # Don't fail the request if storage fails

        return emissions_data

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error calculating parking search emissions: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to calculate parking search emissions: {str(e)}",
        )


@router.get(
    "/estimate_full_parking_journey",
    responses={
        200: {
            "description": "Calculate carbon emissions saved for a complete parking journey: start -> parking slot -> exit",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "start_to_slot": {"distance": 15.2, "path_points": 8},
                        "slot_to_exit": {"distance": 12.8, "path_points": 6},
                        "total_distance": 28.0,
                        "baseline_distance": 95.5,
                        "emissions_factor": 0.194,
                        "actual_emissions": 5.43,
                        "baseline_emissions": 18.53,
                        "emissions_saved": 13.10,
                        "percentage_saved": 70.7,
                        "message": "You saved 13.1g CO₂ (70.7%) by using AutoSpot!",
                        "calculation_method": "dynamic",
                        "map_info": {
                            "building_name": "Westfield Sydney",
                            "map_id": "999999",
                        },
                        "journey_details": {
                            "start_point": {"input": "E1", "level": 1, "x": 0, "y": 3},
                            "parking_slot": {
                                "slot_id": "1A",
                                "level": 1,
                                "x": 8,
                                "y": 3,
                            },
                            "exit_point": {"input": "X1", "level": 1, "x": 15, "y": 8},
                        },
                    }
                }
            },
        },
        400: {
            "description": "Invalid parameters or coordinates",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidCoordinateFormat": {
                            "summary": "Invalid coordinate format",
                            "value": {"detail": "Point must be in 'level,x,y' format."},
                        },
                        "InvalidEntranceId": {
                            "summary": "Entrance ID not found",
                            "value": {
                                "detail": "Entrance 'E99' not found. Use coordinates 'level,x,y' or valid entrance ID."
                            },
                        },
                        "InvalidExitId": {
                            "summary": "Exit ID not found",
                            "value": {
                                "detail": "Exit 'X99' not found. Use coordinates 'level,x,y' or valid exit ID."
                            },
                        },
                        "InvalidSlotId": {
                            "summary": "Parking slot not found",
                            "value": {
                                "detail": "Parking slot 'Z99' not found. Use slot ID or coordinates 'level,x,y'."
                            },
                        },
                        "MalformedCoordinates": {
                            "summary": "Malformed coordinate string",
                            "value": {
                                "detail": "Invalid point format: '1,x'. Use coordinates 'level,x,y' or valid ID."
                            },
                        },
                    }
                }
            },
        },
        404: {
            "description": "Map, parking slot, or path not found",
            "content": {
                "application/json": {
                    "examples": {
                        "MapNotFound": {
                            "summary": "Building or map not found",
                            "value": {"detail": "Map not found"},
                        },
                        "NoMapData": {
                            "summary": "No parking map data available",
                            "value": {
                                "detail": "No parking map data found for the specified map."
                            },
                        },
                        "NoPathToSlot": {
                            "summary": "No route from start to parking slot",
                            "value": {
                                "detail": "No path found from start point to parking slot"
                            },
                        },
                        "NoPathFromSlot": {
                            "summary": "No route from parking slot to exit",
                            "value": {
                                "detail": "No path found from parking slot to exit point"
                            },
                        },
                        "SlotNotFound": {
                            "summary": "Specific parking slot not found",
                            "value": {"detail": "Parking slot '1A' not found"},
                        },
                    }
                }
            },
        },
    },
)
def estimate_min_emissions_for_full_parking_journey(
    start: str = Query(
        ...,
        description="Start point: either 'level,x,y' coordinates or entrance ID (e.g., 'E1', 'BE2')",
        example="E1",
    ),
    slot_id: str = Query(
        ...,
        description="Target parking slot: either slot ID (e.g., '1A', '2C') or coordinates 'level,x,y'",
        example="1A",
    ),
    exit: str = Query(
        ...,
        description="Exit point: either 'level,x,y' coordinates or exit ID (e.g., 'X1', 'BX2')",
        example="X1",
    ),
    building_name: Optional[str] = Query(None, description="Building name"),
    map_id: Optional[str] = Query(None, description="Map ID"),
    use_dynamic_baseline: bool = Query(
        True, description="Whether to calculate baseline based on parking lot size"
    ),
    username: Optional[str] = Query(
        None, description="Username for storing emission history"
    ),
    session_id: Optional[str] = Query(
        None, description="Session ID for associating with parking session"
    ),
):
    """
    Calculate carbon emissions saved for a complete carpark parking journey

    This calculates the total carbon emissions saved for driving to:
    1. **Start point (entrance) -> Parking slot**
    2. **Parking slot -> Exit point**

    The carbon emission saved is calculated based on the **total distance** of both segments
    combined, compared to searching without guidance.
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

        # Helper function to parse coordinates or find entrance/exit by ID
        def resolve_point(point_str: str, point_type: str):
            """
            Resolve a point string to coordinates (level, x, y)
            point_str can be either:
            - Coordinates: "level,x,y"
            - ID: "E1", "BE2", "X1", etc.
            """
            # Try to parse as coordinates first
            if "," in point_str:
                parts = point_str.split(",")
                if len(parts) == 3:
                    try:
                        level, x, y = int(parts[0]), float(parts[1]), float(parts[2])
                        return (level, x, y)
                    except ValueError:
                        pass

            # If not coordinates, treat as ID and search in map data
            if point_type == "start":
                # Look for entrance
                for level_data in parking_map:
                    for entrance in level_data.get("entrances", []):
                        if entrance.get("entrance_id") == point_str:
                            return (
                                entrance.get("level", 1),
                                entrance["x"],
                                entrance["y"],
                            )
                raise ValueError(
                    f"Entrance '{point_str}' not found. Use coordinates 'level,x,y' or valid entrance ID."
                )

            elif point_type == "exit":
                # Look for exit
                for level_data in parking_map:
                    for exit_point in level_data.get("exits", []):
                        if exit_point.get("exit_id") == point_str:
                            return (
                                exit_point.get("level", 1),
                                exit_point["x"],
                                exit_point["y"],
                            )
                raise ValueError(
                    f"Exit '{point_str}' not found. Use coordinates 'level,x,y' or valid exit ID."
                )

            raise ValueError(
                f"Invalid point format: '{point_str}'. Use coordinates 'level,x,y' or valid ID."
            )

        # Resolve start and exit points
        start_pt = resolve_point(start, "start")
        exit_pt = resolve_point(exit, "exit")

        # Helper function to resolve parking slot
        def resolve_slot(slot_str: str):
            """
            Resolve a slot string to slot info and coordinates
            slot_str can be either:
            - Slot ID: "1A", "2C", etc.
            - Coordinates: "level,x,y"
            """
            # Try to parse as coordinates first
            if "," in slot_str:
                parts = slot_str.split(",")
                if len(parts) == 3:
                    try:
                        level, x, y = int(parts[0]), float(parts[1]), float(parts[2])

                        # Check if coordinates match any existing parking slot
                        for level_data in parking_map:
                            for slot in level_data.get("slots", []):
                                slot_level = slot.get("level", 1)
                                slot_x = slot["x"]
                                slot_y = slot["y"]

                                # Check if coordinates match (with small tolerance for floating point comparison)
                                if (
                                    slot_level == level
                                    and abs(slot_x - x) < 0.1
                                    and abs(slot_y - y) < 0.1
                                ):
                                    # Found matching slot: Use actual slot information
                                    return slot, (slot_level, slot_x, slot_y)

                        # No matching slot found, create a virtual slot for coordinates
                        return {
                            "slot_id": f"COORD_{level}_{x}_{y}",
                            "level": level,
                            "x": x,
                            "y": y,
                            "status": "coordinate",
                        }, (level, x, y)
                    except ValueError:
                        pass

            # If not coordinates, treat as slot ID and search in map data
            for level_data in parking_map:
                for slot in level_data.get("slots", []):
                    if slot.get("slot_id") == slot_str:
                        return slot, (slot.get("level", 1), slot["x"], slot["y"])

            raise ValueError(
                f"Parking slot '{slot_str}' not found. Use slot ID or coordinates 'level,x,y'."
            )

        # Resolve parking slot
        target_slot, slot_pt = resolve_slot(slot_id)

        # Create path planner
        planner = PathPlanner(parking_map)

        # Helper function to make slot bidirectional temporarily for pathfinding
        def enable_slot_exit(graph, slot_node):
            """
            Temporarily add bidirectional connection for a parking slot so it can be used as a starting point
            """
            # Find all corridor nodes that connect to this slot and add reverse connections
            for node, connections in graph.items():
                for connected_node, distance in connections:
                    if connected_node == slot_node:
                        # Add reverse connection: slot to corridor
                        if slot_node not in graph:
                            graph[slot_node] = []
                        # Check if reverse connection already exists
                        if not any(conn[0] == node for conn in graph[slot_node]):
                            graph[slot_node].append((node, distance))

        # Calculate path 1: Start to Parking Slot
        path1, distance1 = planner.find_path(start_pt, slot_pt)
        if not path1:
            raise HTTPException(
                status_code=404, detail="No path found from start point to parking slot"
            )

        # Enable slot to be used as starting point for second path
        enable_slot_exit(planner.graph, slot_pt)

        # Calculate path 2: Parking Slot to Exit
        path2, distance2 = planner.find_path(slot_pt, exit_pt)
        if not path2:
            raise HTTPException(
                status_code=404, detail="No path found from parking slot to exit point"
            )

        # Calculate total distance
        total_distance = distance1 + distance2

        # Calculate emissions
        start_coords = (start_pt[1], start_pt[2])  # (x, y) from (level, x, y)

        if use_dynamic_baseline:
            baseline_distance = calculate_dynamic_baseline(parking_map, start_coords)
            calculation_method = "dynamic"
        else:
            baseline_distance = None
            calculation_method = "static"

        emissions_data = calculate_emissions_saved(
            actual_distance=total_distance, baseline_distance=baseline_distance
        )

        # message for the parking journey
        emissions_saved = emissions_data.get("emissions_saved", 0)
        percentage_saved = emissions_data.get("percentage_saved", 0)

        if emissions_saved <= 0:
            journey_message = (
                "No emissions saved - you're already taking an efficient route!"
            )
        else:
            if emissions_saved >= 1000:  # >= 1kg
                amount = emissions_saved / 1000
                unit = "kg"
            else:
                amount = emissions_saved
                unit = "g"
            journey_message = f"You saved {amount:.1f}{unit} CO₂ ({percentage_saved:.1f}%) by using AutoSpot!"

        # Prepare response of the full parking journey
        response_data = {
            **emissions_data,
            "success": True,
            "calculation_method": calculation_method,
            "message": journey_message,
            "start_to_slot": {
                "distance": round(distance1, 2),
                "path_points": len(path1) if path1 else 0,
            },
            "slot_to_exit": {
                "distance": round(distance2, 2),
                "path_points": len(path2) if path2 else 0,
            },
            "total_distance": round(total_distance, 2),
            "map_info": {
                "building_name": map_data.get("building_name"),
                "map_id": str(map_data.get("_id", "")),
            },
            "journey_details": {
                "start_point": {
                    "input": start,
                    "level": start_pt[0],
                    "x": start_pt[1],
                    "y": start_pt[2],
                },
                "parking_slot": {
                    "slot_id": target_slot["slot_id"],
                    "level": target_slot.get("level", 1),
                    "x": target_slot["x"],
                    "y": target_slot["y"],
                    "status": target_slot.get("status", "unknown"),
                },
                "exit_point": {
                    "input": exit,
                    "level": exit_pt[0],
                    "x": exit_pt[1],
                    "y": exit_pt[2],
                },
            },
        }

        # Store emission data automatically
        try:
            record_id = emission_storage.store_emission_record(
                route_distance=response_data["total_distance"],
                baseline_distance=emissions_data["baseline_distance"],
                emissions_factor=emissions_data["emissions_factor"],
                actual_emissions=emissions_data["actual_emissions"],
                baseline_emissions=emissions_data["baseline_emissions"],
                emissions_saved=emissions_data["emissions_saved"],
                percentage_saved=emissions_data["percentage_saved"],
                calculation_method=calculation_method,
                endpoint_used="/emissions/estimate_full_parking_journey",
                username=username,
                session_id=session_id,
                map_info=response_data["map_info"],
                journey_details=response_data["journey_details"],
            )
            if record_id:
                response_data["record_id"] = record_id
        except Exception as e:
            logging.warning(f"Failed to store emission data: {e}")

        return response_data

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error calculating parking journey emissions: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to calculate parking journey emissions: {str(e)}",
        )


@router.get(
    "/factors",
    responses={
        200: {
            "description": "Get current emissions calculation factors and settings",
            "content": {
                "application/json": {
                    "example": {
                        "co2_emissions_per_meter": 0.192,
                        "baseline_search_distance": 100.0,
                        "description": {
                            "emissions_factor": "Grams of CO₂ produced per meter of driving for a typical car",
                            "baseline_distance": "Default distance assumed for searching without guidance",
                        },
                    }
                }
            },
        }
    },
)
def get_emissions_factors():
    """
    Get current emissions calculation factors and settings

    This endpoint returns the current configuration values used for
    carbon emissions calculations, including the CO₂ emissions factor
    and baseline search distance.
    """
    from app.config import settings

    return {
        "co2_emissions_per_meter": settings.co2_emissions_per_meter,
        "baseline_search_distance": settings.baseline_search_distance,
        "description": {
            "emissions_factor": "Grams of CO₂ produced per meter of driving for a typical car",
            "baseline_distance": "Default distance assumed for searching without guidance",
        },
    }


@router.get(
    "/history",
    responses={
        200: {
            "description": "Get emission calculation history",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "records": [
                            {
                                "_id": "60f7b1b3d5c4a1b3d5c4a1b3",
                                "username": "john_doe",
                                "session_id": "session456",
                                "route_distance": 25.5,
                                "emissions_saved": 11.46,
                                "calculation_method": "static",
                                "created_at": "2023-01-01T12:00:00Z",
                            }
                        ],
                        "total_records": 1,
                    }
                }
            },
        }
    },
)
def get_emission_history(
    username: Optional[str] = Query(None, description="Filter by username"),
    session_id: Optional[str] = Query(None, description="Filter by session ID"),
    calculation_method: Optional[str] = Query(
        None, description="Filter by calculation method"
    ),
    limit: int = Query(50, le=100, description="Maximum number of records to return"),
):
    """
    Retrieve emission calculation history with optional filters

    **Parameters:**
    - **username**: (optional) Filter records for specific user
    - **session_id**: (optional) Filter records for specific parking session
    - **calculation_method**: (optional) Filter by calculation method (static/dynamic)
    - **limit**: Maximum number of records to return (max 100)
    """
    try:
        # Create query object
        query = EmissionHistoryQuery(
            username=username,
            session_id=session_id,
            calculation_method=calculation_method,
            limit=limit,
        )

        # Get emission history
        records = emission_storage.get_emission_history(query)

        # Convert ObjectId to string for JSON serialization
        for record in records:
            if "_id" in record:
                record["_id"] = str(record["_id"])

        return {
            "success": True,
            "records": records,
            "total_records": len(records),
            "query_parameters": {
                "username": username,
                "session_id": session_id,
                "calculation_method": calculation_method,
                "limit": limit,
            },
        }

    except Exception as e:
        logging.error(f"Error retrieving emission history: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to retrieve emission history: {str(e)}"
        )


@router.get(
    "/recent",
    responses={
        200: {
            "description": "Get recent emission records",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "records": [
                            {
                                "_id": "60f7b1b3d5c4a1b3d5c4a1b3",
                                "route_distance": 25.5,
                                "emissions_saved": 11.46,
                                "calculation_method": "static",
                                "created_at": "2023-01-01T12:00:00Z",
                            }
                        ],
                        "count": 1,
                    }
                }
            },
        }
    },
)
def get_recent_emissions(
    limit: int = Query(
        10, le=50, description="Number of recent records to return (max 50)"
    )
):
    """
    Get most recent emission calculation records

    **Parameters:**
    - **limit**: Number of recent records to return (maximum 50)
    """
    try:
        records = emission_storage.get_recent_emissions(limit)

        # Convert ObjectId to string for JSON serialization
        for record in records:
            if "_id" in record:
                record["_id"] = str(record["_id"])

        return {"success": True, "records": records, "count": len(records)}

    except Exception as e:
        logging.error(f"Error retrieving recent emissions: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to retrieve recent emissions: {str(e)}"
        )


@router.delete(
    "/clear",
    responses={
        200: {
            "description": "Clear emission records",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "deleted_count": 25,
                        "message": "Deleted 25 emission records for user john_doe",
                    }
                }
            },
        }
    },
)
def clear_emission_records(
    username: Optional[str] = Query(
        None, description="Clear records for specific user"
    ),
    session_id: Optional[str] = Query(
        None, description="Clear records for specific session"
    ),
    confirm: bool = Query(
        False, description="Confirmation flag - must be true to proceed"
    ),
):
    """
    Clear emission records (for testing/cleanup purposes)

    **Parameters:**
    - **username**: (optional) Clear records for specific user only
    - **session_id**: (optional) Clear records for specific session only
    - **confirm**: Must be set to true to confirm deletion

    **Note:** At least one of username or session_id must be provided for safety
    """
    if not confirm:
        raise HTTPException(
            status_code=400, detail="Must set confirm=true to proceed with deletion"
        )

    if not username and not session_id:
        raise HTTPException(
            status_code=400,
            detail="Must provide either username or session_id for safety",
        )

    try:
        deleted_count = emission_storage.delete_emission_records(
            username=username, session_id=session_id
        )

        message = f"Deleted {deleted_count} emission records"
        if username:
            message += f" for user {username}"
        if session_id:
            message += f" for session {session_id}"

        return {"success": True, "deleted_count": deleted_count, "message": message}

    except Exception as e:
        logging.error(f"Error clearing emission records: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to clear emission records: {str(e)}"
        )


@router.get(
    "/estimate-session-journey",
    responses={
        200: {
            "description": "Calculate carbon emissions saved for a parking session journey",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "session_info": {
                            "session_id": "session-12345",
                            "slot_id": "1A",
                            "entrance_id": "E1",
                            "exit_id": "X1",
                            "username": "john_doe",
                        },
                        "start_to_slot": {"distance": 15.2, "path_points": 8},
                        "slot_to_exit": {"distance": 12.8, "path_points": 6},
                        "total_distance": 28.0,
                        "baseline_distance": 95.5,
                        "emissions_factor": 0.194,
                        "actual_emissions": 5.43,
                        "baseline_emissions": 18.53,
                        "emissions_saved": 13.10,
                        "percentage_saved": 70.7,
                        "message": "You saved 13.1g CO₂ (70.7%) by using AutoSpot!",
                        "calculation_method": "dynamic",
                        "record_id": "64f7b1b3d5c4a1b3d5c4a1b3",
                        "map_info": {
                            "building_name": "Westfield Sydney",
                            "map_id": "999999",
                        },
                    }
                }
            },
        },
        400: {
            "description": "Invalid session or missing data",
            "content": {
                "application/json": {
                    "examples": {
                        "MissingEntrance": {
                            "summary": "Session missing entrance_id",
                            "value": {
                                "detail": "Session does not have entrance_id information"
                            },
                        },
                        "MissingExit": {
                            "summary": "Session missing exit_id",
                            "value": {
                                "detail": "Session does not have exit_id information"
                            },
                        },
                    }
                }
            },
        },
        404: {
            "description": "Session or map not found",
            "content": {
                "application/json": {
                    "examples": {
                        "SessionNotFound": {
                            "summary": "Session not found",
                            "value": {"detail": "Session not found"},
                        },
                        "MapNotFound": {
                            "summary": "Map data not found",
                            "value": {"detail": "Map not found"},
                        },
                    }
                }
            },
        },
    },
)
def estimate_session_journey_emissions(
    session_id: str = Query(
        ..., description="Parking session ID", example="session-12345"
    ),
    building_name: Optional[str] = Query(
        None, description="Building name (if not in session data)"
    ),
    map_id: Optional[str] = Query(None, description="Map ID (if not in session data)"),
    use_dynamic_baseline: bool = Query(
        True, description="Whether to calculate baseline based on parking lot size"
    ),
    username: Optional[str] = Query(
        None, description="Username for storing emission history (if not from session)"
    ),
):
    """
    Calculate carbon emissions saved for a complete parking journey using session data

    This endpoint takes a session ID and uses the stored entrance_id, slot_id, and exit_id
    to calculate the total emissions saved for the complete parking journey.

    """
    try:
        # Find the session
        session = session_collection.find_one({"session_id": session_id})
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")

        # Extract session data
        slot_id = session.get("slot_id")
        entrance_id = session.get("entrance_id")
        exit_id = session.get("exit_id")
        session_username = None

        # Get username from user_id in session
        if session.get("user_id"):
            from app.database import user_collection
            from bson import ObjectId

            user = user_collection.find_one({"_id": ObjectId(session["user_id"])})
            if user:
                session_username = user.get("username")

        # Validate required session data
        if not entrance_id:
            raise HTTPException(
                status_code=400, detail="Session does not have entrance_id information"
            )
        if not exit_id:
            raise HTTPException(
                status_code=400, detail="Session does not have exit_id information"
            )
        if not slot_id:
            raise HTTPException(
                status_code=400, detail="Session does not have slot_id information"
            )

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

        # Helper function to resolve entrance/exit/slot coordinates
        def resolve_point(point_str: str, point_type: str):
            """Resolve entrance_id, exit_id, or slot_id to coordinates"""
            # Try to parse as coordinates first
            try:
                parts = point_str.split(",")
                if len(parts) == 3:
                    level, x, y = int(parts[0]), float(parts[1]), float(parts[2])
                    return (level, x, y)
            except ValueError:
                pass

            # Look for entrance/exit/slot by ID
            if point_type == "entrance":
                for level_data in parking_map:
                    for entrance in level_data.get("entrances", []):
                        if entrance.get("entrance_id") == point_str:
                            return (
                                entrance.get("level", 1),
                                entrance["x"],
                                entrance["y"],
                            )
                raise ValueError(f"Entrance '{point_str}' not found")

            elif point_type == "exit":
                for level_data in parking_map:
                    for exit_point in level_data.get("exits", []):
                        if exit_point.get("exit_id") == point_str:
                            return (
                                exit_point.get("level", 1),
                                exit_point["x"],
                                exit_point["y"],
                            )
                raise ValueError(f"Exit '{point_str}' not found")

            elif point_type == "slot":
                for level_data in parking_map:
                    for slot in level_data.get("slots", []):
                        if slot.get("slot_id") == point_str:
                            return (slot.get("level", 1), slot["x"], slot["y"])
                raise ValueError(f"Parking slot '{point_str}' not found")

        # Resolve all points
        entrance_pt = resolve_point(entrance_id, "entrance")
        exit_pt = resolve_point(exit_id, "exit")
        slot_pt = resolve_point(slot_id, "slot")

        # Create path planner
        planner = PathPlanner(parking_map)

        # Helper function to enable slot for pathfinding
        def enable_slot_exit(graph, slot_node):
            """Temporarily add bidirectional connection for a parking slot"""
            for node, connections in graph.items():
                for connected_node, distance in connections:
                    if connected_node == slot_node:
                        if slot_node not in graph:
                            graph[slot_node] = []
                        if not any(conn[0] == node for conn in graph[slot_node]):
                            graph[slot_node].append((node, distance))

        # Calculate path 1: Entrance to Parking Slot
        path1, distance1 = planner.find_path(entrance_pt, slot_pt)
        if not path1:
            raise HTTPException(
                status_code=404, detail="No path found from entrance to parking slot"
            )

        # Enable slot to be used as starting point for second path
        enable_slot_exit(planner.graph, slot_pt)

        # Calculate path 2: Parking Slot to Exit
        path2, distance2 = planner.find_path(slot_pt, exit_pt)
        if not path2:
            raise HTTPException(
                status_code=404, detail="No path found from parking slot to exit"
            )

        # Calculate total distance
        total_distance = distance1 + distance2

        # Calculate emissions
        entrance_coords = (entrance_pt[1], entrance_pt[2])  # (x, y) from (level, x, y)

        if use_dynamic_baseline:
            baseline_distance = calculate_dynamic_baseline(parking_map, entrance_coords)
            calculation_method = "dynamic"
        else:
            baseline_distance = None
            calculation_method = "static"

        emissions_data = calculate_emissions_saved(
            actual_distance=total_distance, baseline_distance=baseline_distance
        )

        # Format journey message
        emissions_saved = emissions_data["emissions_saved"]
        percentage_saved = emissions_data["percentage_saved"]

        # Handle different units for large savings
        if emissions_saved >= 1000:
            amount = emissions_saved / 1000
            unit = "kg"
        else:
            amount = emissions_saved
            unit = "g"

        journey_message = f"You saved {amount:.1f}{unit} CO₂ ({percentage_saved:.1f}%) by using AutoSpot!"

        # Prepare response data
        response_data = {
            **emissions_data,
            "success": True,
            "calculation_method": calculation_method,
            "message": journey_message,
            "session_info": {
                "session_id": session_id,
                "slot_id": slot_id,
                "entrance_id": entrance_id,
                "exit_id": exit_id,
                "username": session_username,
            },
            "start_to_slot": {
                "distance": round(distance1, 2),
                "path_points": len(path1) if path1 else 0,
            },
            "slot_to_exit": {
                "distance": round(distance2, 2),
                "path_points": len(path2) if path2 else 0,
            },
            "total_distance": round(total_distance, 2),
            "map_info": {
                "building_name": map_data.get("building_name"),
                "map_id": str(map_data.get("_id", "")),
            },
        }

        # Store emission data automatically
        try:
            record_id = emission_storage.store_emission_record(
                route_distance=total_distance,
                baseline_distance=emissions_data["baseline_distance"],
                emissions_factor=emissions_data["emissions_factor"],
                actual_emissions=emissions_data["actual_emissions"],
                baseline_emissions=emissions_data["baseline_emissions"],
                emissions_saved=emissions_data["emissions_saved"],
                percentage_saved=emissions_data["percentage_saved"],
                calculation_method=calculation_method,
                endpoint_used="/emissions/estimate-session-journey",
                username=username or session_username,
                session_id=session_id,
                map_info=response_data["map_info"],
                journey_details={
                    "session_info": response_data["session_info"],
                    "start_to_slot": response_data["start_to_slot"],
                    "slot_to_exit": response_data["slot_to_exit"],
                },
            )
            if record_id:
                response_data["record_id"] = record_id
        except Exception as e:
            logging.warning(f"Failed to store emission data: {e}")

        return response_data

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Error calculating session journey emissions: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to calculate session journey emissions: {str(e)}",
        )
