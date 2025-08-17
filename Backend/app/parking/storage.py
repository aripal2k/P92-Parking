"""
Parking lot image and analysis storage module
"""

import os
import shutil
from datetime import datetime
from typing import Dict, Any, List, Optional
from pymongo import MongoClient
from app.config import settings
from app.parking.models import ParkingImageAnalysis
import uuid


class ParkingStorageManager:
    """
    Manager for storing parking lot images and analysis results
    """

    def __init__(self):
        """
        Initialize storage manager with MongoDB connection
        """
        self.client = MongoClient(settings.mongodb_url)
        self.db = self.client[settings.database_name]
        self.collection = self.db.maps
        # Removed examples_dir related logic

    def save_image_and_analysis(
        self,
        temp_image_path: str,
        original_filename: str,
        building_name: str,
        gpt4o_analysis: Dict[str, Any],
        parking_map: List[Dict[str, Any]],
        validation_result: Dict[str, Any],
        grid_size: Dict[str, int],
        file_size: int,
    ) -> str:
        """
        Save analysis to MongoDB (no longer save images locally)

        Args:
            temp_image_path: Temporary image file path
            original_filename: Original uploaded filename
            building_name: Building name
            gpt4o_analysis: GPT-4o analysis results
            parking_map: Generated parking map
            validation_result: Validation results
            grid_size: Grid size used
            file_size: Original file size

        Returns:
            Analysis ID
        """
        # Generate unique analysis ID
        analysis_id = str(uuid.uuid4())
        # No longer generate local image file name
        try:
            # Directly create analysis record, do not save image locally
            analysis_record = ParkingImageAnalysis(
                analysis_id=analysis_id,
                original_filename=original_filename,
                building_name=building_name,
                image_path="",  # No longer save image path
                gpt4o_analysis=gpt4o_analysis,
                parking_map=parking_map,
                validation_result=validation_result,
                grid_size=grid_size,
                file_size=file_size,
            )
            # Save to MongoDB
            result = self.collection.insert_one(analysis_record.dict(by_alias=True))
            print(f"💾 Analysis saved to MongoDB with ID: {result.inserted_id}")
            return analysis_id
        except Exception as e:
            print(f"❌ Failed to save analysis: {e}")
            raise

    def get_analysis_by_id(self, analysis_id: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve analysis by ID

        Args:
            analysis_id: Analysis ID

        Returns:
            Analysis record or None
        """
        try:
            result = self.collection.find_one({"_id": analysis_id})
            return result
        except Exception as e:
            print(f"❌ Failed to retrieve analysis {analysis_id}: {e}")
            return None

    def get_recent_analyses(self, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Get recent analyses

        Args:
            limit: Maximum number of records to return

        Returns:
            List of recent analysis records
        """
        try:
            cursor = self.collection.find().sort("analysis_timestamp", -1).limit(limit)
            return list(cursor)
        except Exception as e:
            print(f"❌ Failed to retrieve recent analyses: {e}")
            return []

    def get_analyses_by_building(self, building_name: str) -> List[Dict[str, Any]]:
        """
        Get analyses for a specific building

        Args:
            building_name: Building name

        Returns:
            List of analysis records for the building
        """
        try:
            cursor = self.collection.find(
                {"building_name": {"$regex": building_name, "$options": "i"}}
            ).sort("analysis_timestamp", -1)
            return list(cursor)
        except Exception as e:
            print(f"❌ Failed to retrieve analyses for building {building_name}: {e}")
            return []

    def delete_analysis(self, analysis_id: str) -> bool:
        """
        Delete analysis and associated image

        Args:
            analysis_id: Analysis ID

        Returns:
            True if deleted successfully
        """
        try:
            # Get analysis record first
            record = self.get_analysis_by_id(analysis_id)
            if not record:
                return False

            # Delete image file
            image_path = record.get("image_path")
            if image_path and os.path.exists(image_path):
                os.remove(image_path)
                print(f"🗑️ Deleted image: {image_path}")

            # Delete from database
            result = self.collection.delete_one({"_id": analysis_id})
            success = result.deleted_count > 0

            if success:
                print(f"🗑️ Deleted analysis: {analysis_id}")

            return success

        except Exception as e:
            print(f"❌ Failed to delete analysis {analysis_id}: {e}")
            return False

    def update_analysis(self, analysis_id: str, updated_data: Dict[str, Any]) -> bool:
        """
        Update analysis record with new data

        Args:
            analysis_id: Analysis ID
            updated_data: Updated analysis data

        Returns:
            True if updated successfully
        """
        try:
            # Add timestamp for last modification
            updated_data["last_modified"] = datetime.utcnow()

            # Update the record
            result = self.collection.update_one(
                {"_id": analysis_id}, {"$set": updated_data}
            )

            success = result.modified_count > 0

            if success:
                print(f"✏️ Updated analysis: {analysis_id}")
            else:
                print(f"⚠️ No changes made to analysis: {analysis_id}")

            return success

        except Exception as e:
            print(f"❌ Failed to update analysis {analysis_id}: {e}")
            return False

    def get_storage_stats(self) -> Dict[str, Any]:
        """
        Get storage statistics

        Returns:
            Storage statistics
        """
        try:
            total_analyses = self.collection.count_documents({})

            # Get total file size
            pipeline = [{"$group": {"_id": None, "total_size": {"$sum": "$file_size"}}}]
            size_result = list(self.collection.aggregate(pipeline))
            total_size = size_result[0]["total_size"] if size_result else 0

            # Count by building
            building_pipeline = [
                {"$group": {"_id": "$building_name", "count": {"$sum": 1}}},
                {"$sort": {"count": -1}},
            ]
            building_stats = list(self.collection.aggregate(building_pipeline))

            return {
                "total_analyses": total_analyses,
                "total_size_bytes": total_size,
                "total_size_mb": round(total_size / (1024 * 1024), 2),
                "building_distribution": building_stats,
                "examples_folder": self.examples_dir,
            }

        except Exception as e:
            print(f"❌ Failed to get storage stats: {e}")
            return {}

    def get_analysis_by_building_name(
        self, building_name: str
    ) -> Optional[Dict[str, Any]]:
        """
        Retrieve analysis by building name

        Args:
            building_name: Building name to search for

        Returns:
            Analysis record or None
        """
        try:
            # Case-insensitive search for building name
            result = self.collection.find_one(
                {"building_name": {"$regex": f"^{building_name}$", "$options": "i"}}
            )
            return result
        except Exception as e:
            print(f"❌ Failed to retrieve analysis for building '{building_name}': {e}")
            return None

    def get_analyses_by_building_name(self, building_name: str) -> List[Dict[str, Any]]:
        """
        Retrieve all analyses for a building name (in case there are multiple)

        Args:
            building_name: Building name to search for

        Returns:
            List of analysis records
        """
        try:
            # Case-insensitive search for building name
            results = list(
                self.collection.find(
                    {"building_name": {"$regex": f"^{building_name}$", "$options": "i"}}
                ).sort("analysis_timestamp", -1)
            )  # Most recent first
            return results
        except Exception as e:
            print(f"❌ Failed to retrieve analyses for building '{building_name}': {e}")
            return []

    def get_analysis_by_building_and_level(
        self, building_name: str, level: int
    ) -> Optional[Dict[str, Any]]:
        """
        Retrieve analysis by building name and level
        Args:
            building_name: Building name to search for
            level: Level to search for
        Returns:
            Analysis record or None
        """
        try:
            # Case-insensitive search for building name and exact match for level
            result = self.collection.find_one(
                {
                    "building_name": {"$regex": f"^{building_name}$", "$options": "i"},
                    "parking_map.level": level,
                }
            )
            return result
        except Exception as e:
            print(
                f"❌ Failed to retrieve analysis for building '{building_name}' at level {level}: {e}"
            )
            return None

    def find_slot_by_id(self, slot_id: str) -> Optional[Dict[str, Any]]:
        """
        Find a specific parking slot by slot_id across all maps (including example map)
        Priority: MongoDB first, then example map as fallback
        """
        try:
            # First, search for slot in MongoDB (prioritize real data)
            pipeline = [
                {"$unwind": "$parking_map"},
                {"$unwind": "$parking_map.slots"},
                {"$match": {"parking_map.slots.slot_id": slot_id}},
                {"$limit": 1},
            ]

            results = list(self.collection.aggregate(pipeline))
            if results:
                result = results[0]
                print(f"Found slot {slot_id} in MongoDB map {result['_id']}")
                return {
                    "slot": result["parking_map"]["slots"],
                    "map_id": result["_id"],
                    "building_name": result["building_name"],
                    "level": result["parking_map"]["level"],
                }

            # Fallback: check example map only if not found in MongoDB
            from app.examples.example_map import example_map
            from app.parking.utils import EXAMPLE_MAP_ID

            for level_data in example_map:
                for slot in level_data.get("slots", []):
                    if slot.get("slot_id") == slot_id:
                        print(f"Found slot {slot_id} in example map (fallback)")
                        return {
                            "slot": slot,
                            "map_id": EXAMPLE_MAP_ID,
                            "building_name": level_data.get(
                                "building", "Westfield Sydney"
                            ),
                            "level": level_data.get("level", 1),
                        }

            print(f"Slot {slot_id} not found in either MongoDB or example map")
            return None

        except Exception as e:
            print(f"Failed to find slot {slot_id}: {e}")
            return None

    def update_slot_status(
        self,
        slot_id: str,
        new_status: str,
        vehicle_id: str = None,
        reserved_by: str = None,
    ) -> bool:
        """
        Update a specific parking slot's status and related fields

        Args:
            slot_id: The slot ID to update
            new_status: New status ("available", "occupied", "allocated")
            vehicle_id: Vehicle ID for occupied slots (optional)
            reserved_by: Username (users' only) for occupied/allocated slots (required for non-available status)
        """
        try:
            # First find the slot to get map and level info
            slot_info = self.find_slot_by_id(slot_id)
            if not slot_info:
                print(f"Slot {slot_id} not found")
                return False

            # Check if this is the example map
            from app.parking.utils import EXAMPLE_MAP_ID

            if slot_info["map_id"] == EXAMPLE_MAP_ID:
                # For example map, we can't actually update the data (it's hardcoded)
                # But we return True to indicate "success" so the session can proceed
                print(
                    f"Simulated update for example map slot {slot_id} status to {new_status}"
                )
                return True

            # Prepare update data for MongoDB maps
            update_data = {
                "parking_map.$[level].slots.$[slot].status": new_status,
                "last_modified": datetime.utcnow(),
            }

            # Handle status-specific fields
            if new_status == "occupied":
                update_data["parking_map.$[level].slots.$[slot].vehicle_id"] = (
                    vehicle_id
                )
                update_data["parking_map.$[level].slots.$[slot].reserved_by"] = (
                    reserved_by
                )
            elif new_status == "allocated":
                update_data["parking_map.$[level].slots.$[slot].reserved_by"] = (
                    reserved_by
                )
                update_data["parking_map.$[level].slots.$[slot].vehicle_id"] = (
                    vehicle_id  # Save vehicle_id for allocated status
                )
            elif new_status == "available":
                update_data["parking_map.$[level].slots.$[slot].vehicle_id"] = None
                update_data["parking_map.$[level].slots.$[slot].reserved_by"] = None

            # Update using array filters
            result = self.collection.update_one(
                {"_id": slot_info["map_id"]},
                {"$set": update_data},
                array_filters=[
                    {"level.level": slot_info["level"]},
                    {"slot.slot_id": slot_id},
                ],
            )

            success = result.modified_count > 0
            if success:
                print(f"Updated slot {slot_id} status to {new_status}")
            else:
                print(f"No changes made to slot {slot_id}")

            return success

        except Exception as e:
            print(f"Failed to update slot {slot_id}: {e}")
            return False

    def get_slots_by_criteria(
        self,
        map_id: str = None,
        building_name: str = None,
        level: int = None,
        status_filter: str = None,
    ) -> List[Dict[str, Any]]:
        """
        Get parking slots based on various criteria

        Args:
            map_id: Optional map ID filter
            building_name: Optional building name filter
            level: Optional level filter
            status_filter: Optional status filter ("available", "occupied", "allocated")

        Returns:
            List of slots with map context information
        """
        try:
            # Build match criteria
            match_criteria = {}

            if map_id:
                match_criteria["_id"] = map_id
            elif building_name:
                match_criteria["building_name"] = {
                    "$regex": f"^{building_name}$",
                    "$options": "i",
                }

            # Build aggregation pipeline
            pipeline = [
                {"$match": match_criteria},
                {"$unwind": "$parking_map"},
                {"$unwind": "$parking_map.slots"},
            ]

            # Add level filter if specified
            if level is not None:
                pipeline.append({"$match": {"parking_map.level": level}})

            # Add status filter if specified
            if status_filter:
                pipeline.append({"$match": {"parking_map.slots.status": status_filter}})

            # Project the final structure
            pipeline.append(
                {
                    "$project": {
                        "slot_id": "$parking_map.slots.slot_id",
                        "status": "$parking_map.slots.status",
                        "x": "$parking_map.slots.x",
                        "y": "$parking_map.slots.y",
                        "level": "$parking_map.slots.level",
                        "vehicle_id": "$parking_map.slots.vehicle_id",
                        "reserved_by": "$parking_map.slots.reserved_by",
                        "map_id": "$_id",
                        "building_name": "$building_name",
                        "map_level": "$parking_map.level",
                    }
                }
            )

            results = list(self.collection.aggregate(pipeline))
            return results

        except Exception as e:
            print(f"Failed to get slots by criteria: {e}")
            return []


# Global storage manager instance
storage_manager = ParkingStorageManager()
