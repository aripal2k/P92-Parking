"""
Store example_map to local MongoDB
Simple function to store example_map.py data to local MongoDB
"""

import uuid
from datetime import datetime
from typing import Dict, Any
from app.database import db
from app.examples.example_map import example_map


def store_example_map_to_local(
    building_name: str = "Westfield Sydney1",
    map_id: str = "888888",
    description: str = "Example parking map",
) -> Dict[str, Any]:
    """
    Store example_map data to local MongoDB

    Args:
        building_name: Name of the building (default: "Westfield Sydney1")
        map_id: Custom map ID (default: "888888")
        description: Description of the map

    Returns:
        Dict with success status and details
    """
    try:
        # Get maps collection from local database
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

        return {
            "success": True,
            "operation": operation,
            "map_id": map_id,
            "building_name": building_name,
            "total_slots": total_slots,
            "database": "local",
            "message": f"Example map {operation} successfully to local MongoDB",
        }

    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "database": "local",
            "message": f"Failed to store example map: {str(e)}",
        }


def get_example_maps_from_local() -> Dict[str, Any]:
    """
    Get all example maps from local MongoDB

    Returns:
        Dict with maps data
    """
    try:
        maps_collection = db["maps"]
        example_maps = list(maps_collection.find({"is_example": True}))

        return {
            "success": True,
            "maps": example_maps,
            "total": len(example_maps),
            "database": "local",
            "message": f"Found {len(example_maps)} example maps in local MongoDB",
        }

    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "database": "local",
            "message": f"Failed to retrieve example maps: {str(e)}",
        }


def delete_example_map_from_local(map_id: str) -> Dict[str, Any]:
    """
    Delete an example map from local MongoDB

    Args:
        map_id: ID of the map to delete

    Returns:
        Dict with success status and details
    """
    try:
        maps_collection = db["maps"]
        result = maps_collection.delete_one({"_id": map_id, "is_example": True})

        if result.deleted_count > 0:
            return {
                "success": True,
                "database": "local",
                "message": f"Example map with ID {map_id} deleted successfully from local MongoDB",
            }
        else:
            return {
                "success": False,
                "database": "local",
                "message": f"No example map found with ID {map_id} in local MongoDB",
            }

    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "database": "local",
            "message": f"Failed to delete example map from local MongoDB: {str(e)}",
        }


def test_local_connection() -> Dict[str, Any]:
    """
    Test connection to local MongoDB

    Returns:
        Dict with connection status
    """
    try:
        # Test database connection
        collections = db.list_collection_names()

        # Test maps collection
        maps_collection = db["maps"]
        maps_count = maps_collection.count_documents({})
        example_maps_count = maps_collection.count_documents({"is_example": True})

        return {
            "success": True,
            "database": "local",
            "collections": collections,
            "total_maps": maps_count,
            "example_maps": example_maps_count,
            "message": "Local MongoDB connection successful",
        }

    except Exception as e:
        return {
            "success": False,
            "database": "local",
            "error": str(e),
            "message": f"Local MongoDB connection failed: {str(e)}",
        }


# Simple usage example
if __name__ == "__main__":
    print("🚗 Store example_map to Local MongoDB")
    print("=" * 40)

    # Test connection first
    print("1. Testing local MongoDB connection...")
    connection_result = test_local_connection()

    if connection_result["success"]:
        print("✅ Local MongoDB connection successful!")
        print(f"   Collections: {connection_result['collections']}")
        print(f"   Total Maps: {connection_result['total_maps']}")
        print(f"   Example Maps: {connection_result['example_maps']}")

        # Store example_map to local MongoDB
        print("\n2. Storing example map to local MongoDB...")
        result = store_example_map_to_local(
            building_name="Westfield Sydney1",
            map_id="888888",
            description="Example map from example_map.py stored locally",
        )

        if result["success"]:
            print("✅ Successfully stored to local MongoDB!")
            print(f"   Map ID: {result['map_id']}")
            print(f"   Building: {result['building_name']}")
            print(f"   Total Slots: {result['total_slots']}")
            print(f"   Operation: {result['operation']}")
        else:
            print("❌ Failed to store to local MongoDB!")
            print(f"   Error: {result['message']}")

        # Get all example maps
        print("\n3. Retrieving example maps from local MongoDB...")
        maps_result = get_example_maps_from_local()

        if maps_result["success"]:
            print(f"✅ Found {maps_result['total']} example maps:")
            for i, map_data in enumerate(maps_result["maps"], 1):
                print(f"   {i}. {map_data['building_name']} (ID: {map_data['_id']})")
        else:
            print("❌ Failed to retrieve maps!")
            print(f"   Error: {maps_result['message']}")
    else:
        print("❌ Local MongoDB connection failed!")
        print(f"   Error: {connection_result['message']}")

    print("\n" + "=" * 40)
    print("✅ Local MongoDB test completed!")
