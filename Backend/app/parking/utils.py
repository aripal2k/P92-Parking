import math
import heapq
import json
import os
from datetime import datetime, time
from typing import Dict, Any, Tuple
from app.parking.models import (
    ParkingFareRequest,
    ParkingFareResponse,
    ParkingRatesConfig,
)
from app.examples.example_map import example_map
from app.parking.storage import storage_manager
from fastapi import HTTPException
from typing import Optional, Dict, Any
from app.database import parking_rates_collection

# Constants for example map handling
EXAMPLE_MAP_ID = "999999"
EXAMPLE_BUILDINGS = [
    "westfield sydney",
    "westfield sydney1",
    "westfield",
    "example",
    "westfield a02",
]


def get_map_data(map_id: Optional[str] = None, building_name: Optional[str] = None):
    """
    support example map and database map

    Priority order:
    1. If map_id is specifically the example map ID, return example data
    2. Try to get data from database first (prioritize real data over example data)
    3. Fall back to example data only if no database data found and building matches example buildings

    Args:
        map_id: 999999 is example map
        building_name: building name

    Returns:
        dict:
        {
            "_id": "map id",
            "building_name": "building name",
            "parking_map": [...],
            "source": "example" or "database"
        }

    Raises:
        HTTPException: when map not found
    """
    import logging

    # Check if specifically requesting example map by ID
    if map_id == EXAMPLE_MAP_ID:
        logging.info(f"Returning example map by ID: {EXAMPLE_MAP_ID}")
        return {
            "_id": EXAMPLE_MAP_ID,
            "building_name": "Westfield Sydney",
            "parking_map": example_map,
            "source": "example",
        }

    # Try to get map from database first
    map_data = None
    if map_id:
        logging.info(f"Looking for map with ID: {map_id}")
        map_data = storage_manager.get_analysis_by_id(map_id)
        if not map_data:
            logging.error(f"Map with ID '{map_id}' not found")
            raise HTTPException(
                status_code=404, detail=f"Map with ID '{map_id}' not found"
            )
    elif building_name:
        # Make building name comparison case-insensitive
        logging.info(f"Looking for map with building name: {building_name}")
        map_data = storage_manager.get_analysis_by_building_name(building_name)

    # If we found database data, return it
    if map_data:
        logging.info(f"Found map in database: {map_data.get('_id')}")
        map_data["source"] = "database"
        return map_data

    # Use example data only if building name matches example buildings
    if building_name:
        building_name_lower = building_name.lower()
        # Make building name comparison case-insensitive
        example_matches = [b.lower() for b in EXAMPLE_BUILDINGS]

        if any(
            example_match in building_name_lower or building_name_lower in example_match
            for example_match in example_matches
        ):
            logging.info(
                f"Building name '{building_name}' matches example building, returning example map"
            )
            return {
                "_id": EXAMPLE_MAP_ID,
                "building_name": "Westfield Sydney",
                "parking_map": example_map,
                "source": "example",
            }

        logging.error(
            f"No map found for building '{building_name}'. Available example buildings: {EXAMPLE_BUILDINGS}"
        )
        raise HTTPException(
            status_code=404, detail=f"No map found for building '{building_name}'"
        )

    # if no parameter is provided, return None (let the caller decide how to handle)
    logging.warning("No map_id or building_name provided")
    return None


def euclidean_distance(a, b):
    """Calculate the Euclidean distance between two points"""
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2)


def build_graph_from_corridors(corridors):
    """Convert corridor data to a directed graph structure, all edge weights set to 1"""
    graph = {}
    for corridor in corridors:
        pts = corridor["points"]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            weight = 1
            if corridor["direction"] in ["forward", "both"]:
                graph.setdefault(a, []).append((b, weight))
            if corridor["direction"] in ["backward", "both"]:
                graph.setdefault(b, []).append((a, weight))
    return graph


def connect_entrances_exits_to_corridors(graph, entrances, exits, corridors):
    """
    Automatically connect each entrance to the nearest corridor point (bidirectional),
    and each exit to the nearest corridor point (corridor->exit, unidirectional). All edge weights set to 1.
    """
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
    for x in exits:
        min_dist, min_pt = float("inf"), None
        for corridor in corridors:
            for pt in corridor["points"]:
                d = euclidean_distance(x, pt)
                if d < min_dist:
                    min_dist, min_pt = d, pt
        if min_pt:
            graph.setdefault(min_pt, []).append((x, 1))


def connect_slots_to_corridors(graph, slots, corridors):
    """
    Automatically connect each slot to the nearest corridor point (bidirectional). All edge weights set to 1.
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


def build_full_map_graph(map_data):
    """
    Builds a comprehensive, connected graph for the entire building.
    This version ensures all points are correctly linked to their respective level's corridors.
    """
    graph = {}

    # 1. Build the base corridor network for all levels
    for level_data in map_data:
        level = level_data["level"]
        for corridor in level_data.get("corridors", []):
            pts = corridor["points"]
            for i in range(len(pts) - 1):
                a, b = pts[i], pts[i + 1]
                node_a, node_b = (level, a[0], a[1]), (level, b[0], b[1])
                dist = euclidean_distance(a, b)
                if corridor["direction"] in ["forward", "both"]:
                    graph.setdefault(node_a, []).append((node_b, dist))
                if corridor["direction"] in ["backward", "both"]:
                    graph.setdefault(node_b, []).append((node_a, dist))

    # 2. Connect all fixed points (slots, entrances, exits, ramps) to their nearest corridor
    for level_data in map_data:
        level = level_data["level"]
        corridors_on_level = level_data.get("corridors", [])
        if not corridors_on_level:
            continue

        points_to_connect = []
        # Gather all points on the current level
        for slot in level_data.get("slots", []):
            points_to_connect.append(
                {"x": slot["x"], "y": slot["y"], "type": "bi-directional"}
            )
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

        for point in points_to_connect:
            point_node = (level, point["x"], point["y"])
            point_coord = (point["x"], point["y"])
            min_dist, nearest_corridor_node = float("inf"), None

            for corridor in corridors_on_level:
                for pt in corridor["points"]:
                    d = euclidean_distance(point_coord, pt)
                    if d < min_dist:
                        min_dist, nearest_corridor_node = d, (level, pt[0], pt[1])

            if nearest_corridor_node:
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

    # 3. Connect ramps between levels
    for level_data in map_data:
        for ramp in level_data.get("ramps", []):
            from_node = (ramp["level"], ramp["x"], ramp["y"])
            to_node = (ramp["to_level"], ramp["to_x"], ramp["to_y"])
            ramp_cost = 1.0  # Assumed cost for using a ramp
            if ramp.get("direction", "both") == "both":
                graph.setdefault(from_node, []).append((to_node, ramp_cost))
                graph.setdefault(to_node, []).append((from_node, ramp_cost))
            # Future-proofing for one-way ramps
            elif ramp.get("direction") == "up":
                graph.setdefault(from_node, []).append((to_node, ramp_cost))
            elif ramp.get("direction") == "down":
                graph.setdefault(to_node, []).append((from_node, ramp_cost))

    return graph


def connect_node_to_graph(graph, node, map_data):
    """Connects a dynamic node (like a start or end point) to the existing graph."""
    if not node or node in graph:
        return  # No node to add or node already exists

    node_level, node_x, node_y = node
    node_coord = (node_x, node_y)

    # Find the corridors for the node's level
    level_data = next((l for l in map_data if l["level"] == node_level), None)
    if not level_data:
        return  # Level not found

    corridors_on_level = level_data.get("corridors", [])
    if not corridors_on_level:
        return  # No corridors on this level to connect to

    # Find the nearest corridor point on the same level
    min_dist, nearest_corridor_node = float("inf"), None
    for corridor in corridors_on_level:
        for pt in corridor["points"]:
            d = euclidean_distance(node_coord, pt)
            if d < min_dist:
                min_dist = d
                nearest_corridor_node = (node_level, pt[0], pt[1])

    # Add bi-directional connection between the dynamic node and the nearest corridor node
    if nearest_corridor_node:
        dist = euclidean_distance(
            node_coord, (nearest_corridor_node[1], nearest_corridor_node[2])
        )
        graph.setdefault(node, []).append((nearest_corridor_node, dist))
        graph.setdefault(nearest_corridor_node, []).append((node, dist))


def load_parking_rates() -> Dict[str, Any]:
    """
    Load parking rates from MongoDB configuration
    """
    try:
        # Try to load from MongoDB first
        rates_doc = parking_rates_collection.find_one({"config_id": "default"})

        if rates_doc:
            # Convert MongoDB document to dict format for backward compatibility
            rates_config = {
                "currency": rates_doc.get("currency", "AUD"),
                "default_rates": rates_doc.get("default_rates", {}),
                "destinations": rates_doc.get("destinations", {}),
                "peak_hours": rates_doc.get("peak_hours", {}),
                "public_holidays": rates_doc.get("public_holidays", []),
            }
            return rates_config
        else:
            # Fallback: try to load from JSON file for migration purposes
            config_path = os.path.join(
                os.path.dirname(__file__), "..", "config", "parking_rates.json"
            )
            try:
                with open(config_path, "r") as f:
                    json_data = json.load(f)
                    # If JSON exists, migrate it to MongoDB and return it
                    _migrate_json_to_mongodb(json_data)
                    return json_data
            except FileNotFoundError:
                pass

            # Use default rates if neither MongoDB nor JSON found
            return {
                "currency": "AUD",
                "default_rates": {
                    "base_rate_per_hour": 0.0,
                    "peak_hour_surcharge_rate": 0.0,
                    "weekend_surcharge_rate": 0.0,
                    "public_holiday_surcharge_rate": 0.0,
                },
                "destinations": {},
                "peak_hours": {
                    "weekday": {
                        "morning": {"start": "07:00", "end": "09:00"},
                        "evening": {"start": "17:00", "end": "19:00"},
                    }
                },
                "public_holidays": [],
            }
    except Exception as e:
        print(f"Error loading parking rates: {e}")
        # Return default config on any error
        return {
            "currency": "AUD",
            "default_rates": {
                "base_rate_per_hour": 0.0,
                "peak_hour_surcharge_rate": 0.0,
                "weekend_surcharge_rate": 0.0,
                "public_holiday_surcharge_rate": 0.0,
            },
            "destinations": {},
            "peak_hours": {
                "weekday": {
                    "morning": {"start": "07:00", "end": "09:00"},
                    "evening": {"start": "17:00", "end": "19:00"},
                }
            },
            "public_holidays": [],
        }


def _migrate_json_to_mongodb(json_data: Dict[str, Any]) -> None:
    """
    Helper function to migrate JSON parking rates data to MongoDB
    """
    try:
        from app.parking.models import (
            ParkingRatesConfig,
            DestinationRates,
            PeakHours,
            WeekdayPeakHours,
            PeakHourTime,
        )

        # Convert JSON structure to Pydantic models
        default_rates = DestinationRates(**json_data.get("default_rates", {}))

        # Convert destinations
        destinations = {}
        for dest_name, dest_rates in json_data.get("destinations", {}).items():
            destinations[dest_name] = DestinationRates(**dest_rates)

        # Convert peak hours
        peak_hours_data = json_data.get("peak_hours", {})
        weekday_data = peak_hours_data.get("weekday", {})
        morning_time = PeakHourTime(
            **weekday_data.get("morning", {"start": "07:00", "end": "09:00"})
        )
        evening_time = PeakHourTime(
            **weekday_data.get("evening", {"start": "17:00", "end": "19:00"})
        )
        weekday_peak = WeekdayPeakHours(morning=morning_time, evening=evening_time)
        peak_hours = PeakHours(weekday=weekday_peak)

        # Create the complete config
        config = ParkingRatesConfig(
            config_id="default",
            currency=json_data.get("currency", "AUD"),
            default_rates=default_rates,
            destinations=destinations,
            peak_hours=peak_hours,
            public_holidays=json_data.get("public_holidays", []),
        )

        # Save to MongoDB
        save_parking_rates_to_mongodb(config.dict(by_alias=True))
        print("Successfully migrated parking rates from JSON to MongoDB")

    except Exception as e:
        print(f"Error migrating JSON to MongoDB: {e}")


def save_parking_rates_to_mongodb(rates_config: Dict[str, Any]) -> bool:
    """
    Save parking rates configuration to MongoDB
    """
    try:
        # Ensure config_id is set
        if "config_id" not in rates_config:
            rates_config["config_id"] = "default"

        # Update last_updated timestamp
        rates_config["last_updated"] = datetime.utcnow()

        # Use upsert to replace existing config or create new one
        result = parking_rates_collection.replace_one(
            {"config_id": rates_config["config_id"]}, rates_config, upsert=True
        )

        print(
            f"Parking rates configuration saved to MongoDB successfully. Modified: {result.modified_count}, Upserted: {result.upserted_id}"
        )
        return True

    except Exception as e:
        print(f"Failed to save parking rates configuration to MongoDB: {e}")
        return False


def parse_datetime(date_str: str = None, time_str: str = None) -> datetime:
    """
    Parse date and time strings into a datetime object.
    If date_str or time_str is None, use current Sydney time.
    """
    return datetime.strptime(f"{date_str} {time_str}", "%Y-%m-%d %H:%M")


def is_peak_hour(dt: datetime, rates_config: Dict[str, Any]) -> bool:
    """
    Determine if the given datetime falls within peak hours
    """
    # Only check peak hours for weekdays (Monday=0, Sunday=6)
    if dt.weekday() >= 5:  # Weekend (Saturday=5, Sunday=6)
        return False

    peak_hours = rates_config.get("peak_hours", {}).get("weekday", {})
    current_time = dt.time()

    # Check morning peak
    morning = peak_hours.get("morning", {})
    if morning:
        morning_start = time.fromisoformat(morning["start"])
        morning_end = time.fromisoformat(morning["end"])
        if morning_start <= current_time <= morning_end:
            return True

    # Check evening peak
    evening = peak_hours.get("evening", {})
    if evening:
        evening_start = time.fromisoformat(evening["start"])
        evening_end = time.fromisoformat(evening["end"])
        if evening_start <= current_time <= evening_end:
            return True

    return False


def is_weekend(dt: datetime) -> bool:
    """
    Determine if the given datetime falls on a weekend
    """
    return dt.weekday() >= 5  # Saturday=5, Sunday=6


def is_public_holiday(dt: datetime, rates_config: Dict[str, Any]) -> bool:
    """
    Determine if the given datetime falls on a public holiday
    """
    date_str = dt.strftime("%Y-%m-%d")
    public_holidays = rates_config.get("public_holidays", [])
    return date_str in public_holidays


def get_destination_rates(
    destination: str, rates_config: Dict[str, Any]
) -> Dict[str, float]:
    """
    Get the rates for a specific destination, falling back to default rates
    """
    destinations = rates_config.get("destinations", {})
    default_rates = rates_config.get("default_rates", {})

    if destination in destinations:
        return destinations[destination]
    else:
        return default_rates


def calculate_parking_end_time(start_time_str: str, duration_hours: float) -> str:
    """
    Calculate parking end time using start time and duration with %24 hour handling
    """
    from datetime import datetime, timedelta

    # Parse start time
    start_time = datetime.strptime(start_time_str, "%H:%M").time()

    # Convert to datetime object for calculation (using today's date)
    start_datetime = datetime.combine(datetime.today(), start_time)

    # Add duration
    end_datetime = start_datetime + timedelta(hours=duration_hours)

    # Return time in HH:MM format (handles day rollover)
    return end_datetime.strftime("%H:%M")


def calculate_parking_fare(request: ParkingFareRequest) -> ParkingFareResponse:
    """
    Calculate parking fare based on the request parameters and rules
    """
    # Load rates configuration
    rates_config = load_parking_rates()

    # Parse datetime
    parking_datetime = parse_datetime(request.date, request.time)

    # Get destination-specific rates
    destination_rates = get_destination_rates(request.destination, rates_config)

    # Base calculations - round both rates and hours to 2 decimal places
    base_rate_per_hour = round(destination_rates.get("base_rate_per_hour", 0.0), 2)
    duration_hours_rounded = round(request.duration_hours, 2)
    total_base_cost = base_rate_per_hour * duration_hours_rounded

    # Determine conditions
    is_peak = is_peak_hour(parking_datetime, rates_config)
    is_wknd = is_weekend(parking_datetime)
    is_holiday = is_public_holiday(parking_datetime, rates_config)

    # Calculate surcharges
    peak_hour_surcharge = 0.0
    weekend_surcharge = 0.0
    public_holiday_surcharge = 0.0

    if is_peak:
        peak_rate = destination_rates.get("peak_hour_surcharge_rate", 0.0)
        peak_hour_surcharge = total_base_cost * peak_rate

    if is_wknd:
        weekend_rate = destination_rates.get("weekend_surcharge_rate", 0.0)
        weekend_surcharge = total_base_cost * weekend_rate

    if is_holiday:
        holiday_rate = destination_rates.get("public_holiday_surcharge_rate", 0.0)
        public_holiday_surcharge = total_base_cost * holiday_rate

    # Calculate total fare
    total_fare = (
        total_base_cost
        + peak_hour_surcharge
        + weekend_surcharge
        + public_holiday_surcharge
    )

    # Round all monetary values to 2 decimal places
    base_rate_per_hour = round(base_rate_per_hour, 2)
    total_base_cost = round(total_base_cost, 2)
    peak_hour_surcharge = round(peak_hour_surcharge, 2)
    weekend_surcharge = round(weekend_surcharge, 2)
    public_holiday_surcharge = round(public_holiday_surcharge, 2)
    total_fare = round(total_fare, 2)

    # Calculate end time
    start_time = request.time if request.time else parking_datetime.strftime("%H:%M")
    end_time = calculate_parking_end_time(start_time, duration_hours_rounded)

    # Create breakdown
    breakdown = {
        "base_rate_per_hour": base_rate_per_hour,
        "total_duration_base_cost": total_base_cost,
        "peak_hour_surcharge": peak_hour_surcharge,
        "weekend_surcharge": weekend_surcharge,
        "public_holiday_surcharge": public_holiday_surcharge,
        "total": total_fare,
    }

    return ParkingFareResponse(
        destination=request.destination,
        parking_date=(
            request.date if request.date else parking_datetime.strftime("%Y-%m-%d")
        ),
        parking_start_time=start_time,
        parking_end_time=end_time,
        duration_hours=duration_hours_rounded,
        breakdown=breakdown,
        currency="AUD",
    )
