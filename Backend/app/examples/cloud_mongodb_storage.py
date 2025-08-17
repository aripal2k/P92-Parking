"""
Store example_map to cloud MongoDB
Simple function to store example_map.py data to cloud MongoDB
"""

import uuid
from datetime import datetime
from typing import Dict, Any
from pymongo import MongoClient
from app.examples.example_map import example_map


def store_example_map_to_cloud(
    building_name: str = "Westfield Sydney1",
    map_id: str = "888888",
    description: str = "Example parking map",
) -> Dict[str, Any]:
    """
    Store example_map data to cloud MongoDB

    Args:
        building_name: Name of the building (default: "Westfield Sydney1")
        map_id: Custom map ID (default: "888888")
        description: Description of the map

    Returns:
        Dict with success status and details
    """
    try:
        # Connect to cloud MongoDB
        client = MongoClient("mongodb://54.156.215.128:27017")
        db = client["parking_app"]
        maps_collection = db["maps"]

        # Calculate total slots
        total_slots = 0
        for level in example_map:
            total_slots += len(level.get("slots", []))

        # Create document
        map_document = {
            "_id": map_id,
            "building_name": building_name,
            "original_filename": "example_map.py",
            "upload_timestamp": datetime.utcnow().isoformat() + "Z",
            "parking_map": example_map,
            "grid_size": {"rows": 6, "cols": 6},
            "total_slots": total_slots,
            "analysis_engine": "example_data",
            "description": description,
            "is_example": True,
            "source": "example_map.py",
            "o3_analysis": {
                "source": "example_data",
                "total_slots": total_slots,
                "analysis_timestamp": datetime.utcnow().isoformat() + "Z",
            },
        }

        # Check if map already exists
        existing_map = maps_collection.find_one({"_id": map_id})
        if existing_map:
            # Update existing map
            maps_collection.update_one({"_id": map_id}, {"$set": map_document})
            operation = "updated"
        else:
            # Insert new map
            maps_collection.insert_one(map_document)
            operation = "inserted"

        client.close()

        return {
            "success": True,
            "operation": operation,
            "map_id": map_id,
            "building_name": building_name,
            "total_slots": total_slots,
            "message": f"Example map {operation} successfully to cloud MongoDB",
        }

    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "message": f"Failed to store example map: {str(e)}",
        }


# Simple usage example
if __name__ == "__main__":
    # Store example_map to cloud MongoDB with specific ID
    result = store_example_map_to_cloud(
        building_name="Westfield Sydney1",
        map_id="999999",
        description="Example map from example_map.py",
    )

    if result["success"]:
        print(f"✅ Success: {result['message']}")
        print(f"   Map ID: {result['map_id']}")
        print(f"   Building: {result['building_name']}")
        print(f"   Total Slots: {result['total_slots']}")
    else:
        print(f"❌ Error: {result['message']}")
