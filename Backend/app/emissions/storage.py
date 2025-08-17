"""
Emissions data storage manager for MongoDB
"""

from typing import List, Optional, Dict, Any
from datetime import datetime
from app.database import emissions_collection
from app.emissions.models import EmissionRecord, EmissionSummary, EmissionHistoryQuery
import logging


class EmissionStorageManager:
    """
    Manager for storing and retrieving emission data from MongoDB
    """

    def __init__(self):
        self.collection = emissions_collection

    def store_emission_record(
        self,
        route_distance: float,
        baseline_distance: float,
        emissions_factor: float,
        actual_emissions: float,
        baseline_emissions: float,
        emissions_saved: float,
        percentage_saved: float,
        calculation_method: str,
        endpoint_used: str,
        username: Optional[str] = None,
        session_id: Optional[str] = None,
        map_info: Optional[Dict[str, Any]] = None,
        journey_details: Optional[Dict[str, Any]] = None,
    ) -> Optional[str]:
        """
        Store an emission calculation record in MongoDB

        Returns:
            Record ID if successful, None if failed
        """
        try:
            emission_record = EmissionRecord(
                username=username,
                session_id=session_id,
                route_distance=route_distance,
                baseline_distance=baseline_distance,
                emissions_factor=emissions_factor,
                actual_emissions=actual_emissions,
                baseline_emissions=baseline_emissions,
                emissions_saved=emissions_saved,
                percentage_saved=percentage_saved,
                calculation_method=calculation_method,
                map_info=map_info,
                journey_details=journey_details,
                endpoint_used=endpoint_used,
            )

            # Convert to dict for MongoDB insertion
            record_dict = emission_record.dict(exclude_unset=True)
            result = self.collection.insert_one(record_dict)

            logging.info(f"Emission record stored with ID: {result.inserted_id}")
            return str(result.inserted_id)

        except Exception as e:
            logging.error(f"Failed to store emission record: {e}")
            return None

    def get_emission_history(self, query: EmissionHistoryQuery) -> List[Dict[str, Any]]:
        """
        Retrieve emission history based on query parameters
        """
        try:
            # Build MongoDB query
            mongo_query = {}

            if query.username:
                mongo_query["username"] = query.username
            if query.session_id:
                mongo_query["session_id"] = query.session_id
            if query.calculation_method:
                mongo_query["calculation_method"] = query.calculation_method

            # Execute query
            cursor = self.collection.find(mongo_query).sort("created_at", -1)
            if query.limit:
                cursor = cursor.limit(query.limit)

            return list(cursor)

        except Exception as e:
            logging.error(f"Failed to retrieve emission history: {e}")
            return []

    def get_emission_summary(
        self, username: Optional[str] = None
    ) -> Optional[EmissionSummary]:
        """
        Get emission summary statistics
        """
        try:
            # Build match query
            match_query = {}
            if username:
                match_query["username"] = username

            # MongoDB aggregation pipeline
            pipeline = [
                {"$match": match_query} if match_query else {"$match": {}},
                {
                    "$group": {
                        "_id": None,
                        "total_records": {"$sum": 1},
                        "total_emissions_saved": {"$sum": "$emissions_saved"},
                        "total_distance_optimized": {"$sum": "$route_distance"},
                        "average_percentage_saved": {"$avg": "$percentage_saved"},
                        "min_date": {"$min": "$created_at"},
                        "max_date": {"$max": "$created_at"},
                    }
                },
            ]

            result = list(self.collection.aggregate(pipeline))

            if not result:
                return EmissionSummary(
                    total_records=0,
                    total_emissions_saved=0.0,
                    total_distance_optimized=0.0,
                    average_percentage_saved=0.0,
                )

            stats = result[0]
            return EmissionSummary(
                total_records=stats.get("total_records", 0),
                total_emissions_saved=stats.get("total_emissions_saved", 0.0),
                total_distance_optimized=stats.get("total_distance_optimized", 0.0),
                average_percentage_saved=stats.get("average_percentage_saved", 0.0),
            )

        except Exception as e:
            logging.error(f"Failed to get emission summary: {e}")
            return None

    def get_recent_emissions(self, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Get most recent emission records (including without username)
        """
        try:
            return list(self.collection.find().sort("created_at", -1).limit(limit))
        except Exception as e:
            logging.error(f"Failed to get recent emissions: {e}")
            return []

    def delete_emission_records(
        self, username: Optional[str] = None, session_id: Optional[str] = None
    ) -> int:
        """
        Delete emission records (for cleanup/testing)

        Returns:
            Number of deleted records
        """
        try:
            query = {}
            if username:
                query["username"] = username
            if session_id:
                query["session_id"] = session_id

            if not query:
                # Safety check - don't delete all records without explicit criteria
                logging.warning(
                    "Attempted to delete all emission records - operation blocked"
                )
                return 0

            result = self.collection.delete_many(query)
            logging.info(f"Deleted {result.deleted_count} emission records")
            return result.deleted_count

        except Exception as e:
            logging.error(f"Failed to delete emission records: {e}")
            return 0


# Create a global instance
emission_storage = EmissionStorageManager()
