from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
from app.session.models import ParkingSession
from app.database import session_collection, user_collection
from app.parking.storage import storage_manager
from app.pathfinding.path_planner import PathPlanner
from app.parking.utils import get_map_data
from bson import ObjectId
import uuid
import logging

router = APIRouter(prefix="/session", tags=["session"])


@router.post(
    "/start",
    responses={
        200: {
            "description": "Parking session started successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Parking session started successfully",
                        "session": {
                            "session_id": "session-uuid-here",
                            "slot_id": "A1",
                            "vehicle_id": "vehicle-123",
                            "user_id": "user-456",
                            "start_time": "2024-01-15T10:00:00Z",
                            "end_time": None,
                            "entrance_id": "E1",
                            "exit_id": "X1",
                            "fee": None,
                        },
                    }
                }
            },
        },
        400: {
            "description": "Bad request - user/vehicle already has active session or slot unavailable",
            "content": {
                "application/json": {
                    "examples": {
                        "UserActiveSession": {
                            "summary": "User already has active session",
                            "value": {
                                "detail": "User already has an active parking session"
                            },
                        },
                        "VehicleActiveSession": {
                            "summary": "Vehicle already has active session",
                            "value": {
                                "detail": "Vehicle already has an active parking session"
                            },
                        },
                        "SlotUnavailable": {
                            "summary": "Parking slot not available",
                            "value": {"detail": "Parking slot A1 is not available"},
                        },
                    }
                }
            },
        },
        403: {
            "description": "Forbidden - slot is allocated to different user or vehicle",
            "content": {
                "application/json": {
                    "examples": {
                        "SlotAllocatedToDifferentUser": {
                            "summary": "Slot allocated to different user",
                            "value": {
                                "detail": "Parking slot A1 is allocated to a different user. You can only start a session in slots allocated to you."
                            },
                        },
                        "SlotAllocatedToDifferentVehicle": {
                            "summary": "Slot allocated to different vehicle",
                            "value": {
                                "detail": "Parking slot A1 is allocated to another vehicle."
                            },
                        },
                    }
                }
            },
        },
        404: {
            "description": "User or slot not found",
            "content": {
                "application/json": {
                    "examples": {
                        "UserNotFound": {
                            "summary": "User not found",
                            "value": {"detail": "User not found"},
                        },
                        "SlotNotFound": {
                            "summary": "Parking slot not found",
                            "value": {"detail": "Parking slot not found"},
                        },
                    }
                }
            },
        },
    },
)
def start_session(
    username: str = Query(..., description="Username"),
    vehicle_id: str = Query(..., description="Vehicle ID"),
    slot_id: str = Query(..., description="Parking slot ID"),
    entrance_id: Optional[str] = Query(None, description="Entrance ID from QR scan"),
    building_name: Optional[str] = Query(
        None, description="Building name for exit calculation"
    ),
    map_id: Optional[str] = Query(None, description="Map ID for exit calculation"),
):
    """
    Start a new parking session for a user

    Each user and vehicle can only have one active session at a time.

    **Slot Availability Rules:**
    - **Available/Free slots**: Open to any user
    - **Allocated slots**: Only accessible if admin allocated the slot to the exact username and vehicle_id combination
    - **Occupied slots**: Not available for new sessions

    """
    try:
        # Verify user exists
        user = user_collection.find_one({"username": username, "role": "user"})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        user_id = str(user["_id"])

        # Check if user already has an active session
        user_active_session = session_collection.find_one(
            {"user_id": user_id, "end_time": None}
        )
        if user_active_session:
            raise HTTPException(
                status_code=400, detail="User already has an active parking session"
            )

        # Check if vehicle already has an active session
        vehicle_active_session = session_collection.find_one(
            {"vehicle_id": vehicle_id, "end_time": None}
        )
        if vehicle_active_session:
            raise HTTPException(
                status_code=400, detail="Vehicle already has an active parking session"
            )

        # Verify slot exists and check availability/allocation
        slot_info = storage_manager.find_slot_by_id(slot_id)
        if not slot_info:
            raise HTTPException(status_code=404, detail="Parking slot not found")

        slot_status = slot_info["slot"]["status"].lower()

        # Check if slot is available for session start
        if slot_status in ["available", "free"]:
            # Standard availability check - slot is free for anyone
            pass
        elif slot_status == "allocated":
            # Special condition for admin-allocated slots
            # User can only start session if username, vehicle_id, and slot_id match the allocation
            slot_reserved_by = slot_info["slot"].get("reserved_by")
            slot_vehicle_id = slot_info["slot"].get("vehicle_id")

            # Check if username matches the reserved_by field
            if slot_reserved_by != username:
                raise HTTPException(
                    status_code=403,
                    detail=f"Parking slot {slot_id} is allocated to a different user. You can only start a session in slots allocated to you.",
                )

            # Check if vehicle_id matches (if slot has a specific vehicle_id allocated)
            if slot_vehicle_id and slot_vehicle_id != vehicle_id:
                raise HTTPException(
                    status_code=403,
                    detail=f"Parking slot {slot_id} is allocated to another vehicle.",
                )

            logging.info(
                f"Admin-allocated slot {slot_id} access granted for user {username} with vehicle {vehicle_id}"
            )
        else:
            # Slot is occupied or in some other unavailable state
            raise HTTPException(
                status_code=400, detail=f"Parking slot {slot_id} is not available"
            )

        # Generate session ID
        session_id = f"session-{uuid.uuid4()}"

        # Calculate nearest exit to the slot
        nearest_exit_id = None
        try:
            if building_name or map_id:
                # Get map data for exit calculation
                map_data = get_map_data(map_id, building_name)
                if map_data:
                    parking_map = map_data.get("parking_map", [])
                    if parking_map:
                        # Use PathPlanner to find nearest exit
                        planner = PathPlanner(parking_map)
                        nearest_exit, distance, path = (
                            planner.find_nearest_exit_to_slot(slot_id)
                        )
                        if nearest_exit:
                            nearest_exit_id = nearest_exit.get("exit_id")
                            logging.info(
                                f"Found nearest exit {nearest_exit_id} to slot {slot_id} (distance: {distance:.2f})"
                            )
                        else:
                            logging.warning(f"No exit found for slot {slot_id}")
                    else:
                        logging.warning(
                            f"No parking map data found for building {building_name} / map {map_id}"
                        )
                else:
                    logging.warning(
                        f"Map data not found for building {building_name} / map {map_id}"
                    )
        except Exception as e:
            logging.error(f"Error calculating nearest exit for slot {slot_id}: {e}")
            # Don't fail the session creation if exit calculation fails

        # Create parking session
        session_data = ParkingSession(
            session_id=session_id,
            slot_id=slot_id,
            vehicle_id=vehicle_id,
            user_id=user_id,
            start_time=datetime.now(timezone.utc),
            entrance_id=entrance_id or "",  # From QR scan
            exit_id=nearest_exit_id or "",  # Calculated nearest exit
        )

        # Save session to database
        session_collection.insert_one(session_data.dict())

        # Update user's current session
        user_collection.update_one(
            {"_id": ObjectId(user_id)}, {"$set": {"current_session_id": session_id}}
        )

        # Update slot status to occupied
        storage_manager.update_slot_status(
            slot_id=slot_id,
            new_status="occupied",
            vehicle_id=vehicle_id,
            reserved_by=username,
        )

        logging.info(
            f"Started parking session {session_id} for user {username} in slot {slot_id}"
        )

        return {
            "success": True,
            "message": "Parking session started successfully",
            "session": session_data.dict(),
        }

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to start parking session: {e}")
        raise HTTPException(status_code=500, detail="Failed to start parking session")


@router.post(
    "/end",
    responses={
        200: {
            "description": "Parking session ended successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Parking session ended successfully",
                        "session": {
                            "session_id": "session-uuid-here",
                            "slot_id": "A1",
                            "vehicle_id": "vehicle-123",
                            "user_id": "user-456",
                            "start_time": "2024-01-15T10:00:00Z",
                            "end_time": "2024-01-15T12:00:00Z",
                            "entrance_id": "E1",
                            "exit_id": "X1",
                        },
                    }
                }
            },
        },
        404: {
            "description": "Active session not found",
            "content": {
                "application/json": {
                    "example": {"detail": "No active parking session found"}
                }
            },
        },
    },
)
def end_session(
    username: str = Query(..., description="Username"),
    vehicle_id: str = Query(..., description="Vehicle ID"),
    session_id: Optional[str] = Query(None, description="Session ID"),
    slot_id: Optional[str] = Query(None, description="Slot ID"),
):
    """
    End an active parking session for a user

    - **username**: User's username
    - **vehicle_id**: Vehicle identifier
    - **session_id**: Optional session ID to end specific session
    - **slot_id**: Optional slot ID to end session in specific slot
    """
    try:
        # Verify user exists
        user = user_collection.find_one({"username": username, "role": "user"})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        user_id = str(user["_id"])

        # Build query to find the session
        session_query = {"user_id": user_id, "vehicle_id": vehicle_id, "end_time": None}

        # Add session_id or slot_id filter if provided
        if session_id:
            session_query["session_id"] = session_id
        elif slot_id:
            session_query["slot_id"] = slot_id

        # Find active session
        active_session = session_collection.find_one(session_query)
        if not active_session:
            if session_id:
                raise HTTPException(
                    status_code=404,
                    detail=f"No active parking session found with session_id {session_id}",
                )
            elif slot_id:
                raise HTTPException(
                    status_code=404,
                    detail=f"No active parking session found in slot {slot_id}",
                )
            else:
                raise HTTPException(
                    status_code=404,
                    detail="No active parking session found for this user and vehicle",
                )

        # Update session with end time (remove fee field)
        end_time = datetime.now(timezone.utc)
        update_data = {"end_time": end_time}

        session_collection.update_one(
            {"session_id": active_session["session_id"]}, {"$set": update_data}
        )

        # Clear user's current session
        user_collection.update_one(
            {"_id": ObjectId(user_id)}, {"$unset": {"current_session_id": ""}}
        )

        # Update slot status to available immediately
        storage_manager.update_slot_status(
            slot_id=active_session["slot_id"], new_status="available"
        )

        # Get updated session for response
        updated_session = session_collection.find_one(
            {"session_id": active_session["session_id"]}
        )
        updated_session.pop("_id", None)  # Remove MongoDB _id for response

        logging.info(
            f"Ended parking session {active_session['session_id']} for user {username}. Slot is now available."
        )

        return {
            "success": True,
            "message": "Parking session ended successfully. Slot is now available.",
            "session": updated_session,
        }

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to end parking session: {e}")
        raise HTTPException(status_code=500, detail="Failed to end parking session")


@router.get(
    "/active",
    responses={
        200: {
            "description": "Active session retrieved successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "session": {
                            "session_id": "session-uuid-here",
                            "slot_id": "A1",
                            "vehicle_id": "vehicle-123",
                            "user_id": "user-456",
                            "start_time": "2024-01-15T10:00:00Z",
                            "end_time": None,
                        },
                    }
                }
            },
        },
        404: {
            "description": "No active session found",
            "content": {
                "application/json": {
                    "example": {"detail": "No active parking session found"}
                }
            },
        },
    },
)
def get_active_session(
    username: Optional[str] = Query(None, description="Username"),
    vehicle_id: Optional[str] = Query(None, description="Vehicle ID"),
):
    """
    Get the active parking session for a user or vehicle

    At least one of the following parameters must be provided:
    - **username**: User's username
    - **vehicle_id**: Vehicle identifier
    """
    try:
        # Validate that at least one parameter is provided
        if not username and not vehicle_id:
            raise HTTPException(
                status_code=400, detail="Either username or vehicle_id must be provided"
            )

        # Build query based on provided parameters
        session_query = {"end_time": None}

        if username:
            # Verify user exists
            user = user_collection.find_one({"username": username, "role": "user"})
            if not user:
                raise HTTPException(status_code=404, detail="User not found")
            session_query["user_id"] = str(user["_id"])

        if vehicle_id:
            session_query["vehicle_id"] = vehicle_id

        # Find active session
        active_session = session_collection.find_one(session_query)
        if not active_session:
            if username and vehicle_id:
                raise HTTPException(
                    status_code=404,
                    detail=f"No active parking session found for user {username} with vehicle {vehicle_id}",
                )
            elif username:
                raise HTTPException(
                    status_code=404,
                    detail=f"No active parking session found for user {username}",
                )
            else:
                raise HTTPException(
                    status_code=404,
                    detail=f"No active parking session found for vehicle {vehicle_id}",
                )

        active_session.pop("_id", None)  # Remove MongoDB _id for response

        return {"success": True, "session": active_session}

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to get active session: {e}")
        raise HTTPException(status_code=500, detail="Failed to get active session")


@router.get(
    "/active-sessions-by-building",
    responses={
        200: {
            "description": "Active sessions count retrieved successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "building_name": "Westfield Sydney",
                        "total_active_sessions": 15,
                        "sessions_by_user": [
                            {
                                "username": "john_doe",
                                "vehicle_id": "vehicle-123",
                                "session_id": "session-uuid-1",
                                "slot_id": "A1",
                                "start_time": "2024-01-15T10:00:00Z",
                            },
                            {
                                "username": "jane_smith",
                                "vehicle_id": "vehicle-456",
                                "session_id": "session-uuid-2",
                                "slot_id": "B5",
                                "start_time": "2024-01-15T11:30:00Z",
                            },
                        ],
                    }
                }
            },
        },
        400: {
            "description": "Bad request - missing building name",
            "content": {
                "application/json": {"example": {"detail": "Building name is required"}}
            },
        },
        404: {
            "description": "Building not found",
            "content": {
                "application/json": {"example": {"detail": "Building not found"}}
            },
        },
    },
)
def get_active_sessions_by_building(
    building_name: str = Query(..., description="Building name"),
    username: Optional[str] = Query(None, description="Filter by specific username"),
    vehicle_id: Optional[str] = Query(
        None, description="Filter by specific vehicle ID"
    ),
):
    """
    Get count of active parking sessions for a specific building

    Optionally filter by username and/or vehicle_id to get more specific results.

    - **building_name**: Name of the building to check
    - **username**: Optional - filter by specific username
    - **vehicle_id**: Optional - filter by specific vehicle ID
    """
    try:
        if not building_name:
            raise HTTPException(status_code=400, detail="Building name is required")

        # Verify building exists by checking if there are any slots for this building
        building_slots = storage_manager.get_slots_by_criteria(
            building_name=building_name
        )
        if not building_slots:
            raise HTTPException(status_code=404, detail="Building not found")

        # Get all slot IDs for this building
        building_slot_ids = [slot["slot_id"] for slot in building_slots]

        # Build query for active sessions in this building
        session_query = {
            "end_time": None,  # Active sessions
            "slot_id": {"$in": building_slot_ids},
        }

        # Add username filter if provided
        if username:
            user = user_collection.find_one({"username": username, "role": "user"})
            if user:
                session_query["user_id"] = str(user["_id"])
            else:
                # If username provided but not found, return empty result
                return {
                    "success": True,
                    "building_name": building_name,
                    "total_active_sessions": 0,
                    "sessions_by_user": [],
                }

        # Add vehicle_id filter if provided
        if vehicle_id:
            session_query["vehicle_id"] = vehicle_id

        # Get active sessions
        active_sessions = list(session_collection.find(session_query))

        # Prepare detailed session information
        sessions_by_user = []
        for session in active_sessions:
            # Get username for each session
            user = user_collection.find_one({"_id": ObjectId(session["user_id"])})
            session_info = {
                "username": user["username"] if user else "Unknown",
                "vehicle_id": session["vehicle_id"],
                "session_id": session["session_id"],
                "slot_id": session["slot_id"],
                "start_time": (
                    session["start_time"].isoformat()
                    if isinstance(session["start_time"], datetime)
                    else session["start_time"]
                ),
            }
            sessions_by_user.append(session_info)

        logging.info(
            f"Found {len(active_sessions)} active sessions for building {building_name}"
        )

        return {
            "success": True,
            "building_name": building_name,
            "total_active_sessions": len(active_sessions),
            "sessions_by_user": sessions_by_user,
        }

    except HTTPException:
        raise
    except Exception as e:
        logging.error(
            f"Failed to get active sessions for building {building_name}: {e}"
        )
        raise HTTPException(status_code=500, detail="Failed to get active sessions")


@router.get(
    "/history",
    responses={
        200: {
            "description": "Session history retrieved successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "total_sessions": 25,
                        "sessions": [
                            {
                                "session_id": "session-uuid-1",
                                "slot_id": "A1",
                                "vehicle_id": "vehicle-123",
                                "start_time": "2024-01-15T10:00:00Z",
                                "end_time": "2024-01-15T12:00:00Z",
                            }
                        ],
                    }
                }
            },
        }
    },
)
def get_session_history(
    username: str = Query(..., description="Username"),
    limit: int = Query(
        10, description="Maximum number of sessions to return", ge=1, le=100
    ),
):
    """
    Get parking session history for a user

    - **username**: User's username
    - **limit**: Maximum number of sessions to return (1-100)
    """
    try:
        # Verify user exists
        user = user_collection.find_one({"username": username, "role": "user"})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        user_id = str(user["_id"])

        # Get session history, sorted by start time (most recent first)
        sessions = list(
            session_collection.find({"user_id": user_id})
            .sort("start_time", -1)
            .limit(limit)
        )

        # Remove MongoDB _id from each session
        for session in sessions:
            session.pop("_id", None)
            # Convert datetime objects to ISO strings for JSON serialization
            if isinstance(session.get("start_time"), datetime):
                session["start_time"] = session["start_time"].isoformat()
            if isinstance(session.get("end_time"), datetime):
                session["end_time"] = session["end_time"].isoformat()

        total_sessions = session_collection.count_documents({"user_id": user_id})

        return {"success": True, "total_sessions": total_sessions, "sessions": sessions}

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to get session history for user {username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get session history")


@router.delete(
    "/clear-all",
    responses={
        200: {
            "description": "All user sessions cleared successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "All sessions cleared for user",
                        "deleted_count": 2,
                    }
                }
            },
        },
        404: {
            "description": "User not found",
            "content": {"application/json": {"example": {"detail": "User not found"}}},
        },
    },
)
def clear_all_user_sessions(
    username: str = Query(..., description="Username to clear all sessions for"),
    vehicle_id: Optional[str] = Query(
        None, description="Vehicle ID to clear sessions for"
    ),
):
    """
    Clear all sessions (active and inactive) for a user

    This is a development/cleanup endpoint that removes ALL session records
    for a user, regardless of status. Use when session data gets corrupted.
    """
    try:
        # Verify user exists
        user = user_collection.find_one({"username": username, "role": "user"})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        user_id = str(user["_id"])

        # Build query to find sessions
        session_query = {"user_id": user_id}
        if vehicle_id:
            session_query["vehicle_id"] = vehicle_id

        # Get all sessions before deletion for cleanup
        sessions_to_delete = list(session_collection.find(session_query))

        # Clear all sessions for this user
        result = session_collection.delete_many(session_query)

        # Clear user's current session reference
        user_collection.update_one(
            {"_id": ObjectId(user_id)}, {"$unset": {"current_session_id": ""}}
        )

        # Update any slots that were occupied by these sessions
        for session in sessions_to_delete:
            if session.get("end_time") is None:  # Was an active session
                storage_manager.update_slot_status(
                    slot_id=session["slot_id"], new_status="available"
                )

        logging.info(f"Cleared {result.deleted_count} sessions for user {username}")

        return {
            "success": True,
            "message": f"All sessions cleared for user {username}",
            "deleted_count": result.deleted_count,
        }

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to clear sessions for user {username}: {str(e)}")
        raise HTTPException(
            status_code=500, detail=f"Failed to clear sessions: {str(e)}"
        )


@router.delete(
    "/delete",
    responses={
        200: {
            "description": "Session deleted successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Session deleted successfully",
                        "deleted_session": {
                            "session_id": "session-uuid-here",
                            "slot_id": "A1",
                            "vehicle_id": "vehicle-123",
                            "user_id": "user-456",
                            "start_time": "2024-01-15T10:00:00Z",
                            "end_time": None,
                        },
                    }
                }
            },
        },
        404: {
            "description": "Session not found",
            "content": {
                "application/json": {"example": {"detail": "Session not found"}}
            },
        },
    },
)
def delete_session(
    session_id: str = Query(..., description="Session ID to delete"),
    username: Optional[str] = Query(None, description="Username for verification"),
    vehicle_id: Optional[str] = Query(None, description="Vehicle ID for verification"),
):
    """
    Delete a parking session completely from the database

    This is different from ending a session - this completely removes the session record.
    Use this for development/testing or when you need to completely remove session data.

    - **session_id**: The session ID to delete
    - **username**: Optional - verify the session belongs to this user
    - **vehicle_id**: Optional - verify the session belongs to this vehicle
    """
    try:
        # Build query to find the session
        session_query = {"session_id": session_id}

        # Add verification filters if provided
        if username:
            user = user_collection.find_one({"username": username, "role": "user"})
            if not user:
                raise HTTPException(status_code=404, detail="User not found")
            session_query["user_id"] = str(user["_id"])

        if vehicle_id:
            session_query["vehicle_id"] = vehicle_id

        # Find the session
        session = session_collection.find_one(session_query)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")

        # Store session info for response
        deleted_session = session.copy()
        deleted_session.pop("_id", None)  # Remove MongoDB _id for response

        # Delete the session from database
        result = session_collection.delete_one({"session_id": session_id})

        if result.deleted_count == 0:
            raise HTTPException(status_code=404, detail="Session not found")

        # If this was an active session, also clear user's current session reference
        if session.get("end_time") is None:
            user_collection.update_one(
                {"_id": ObjectId(session["user_id"])},
                {"$unset": {"current_session_id": ""}},
            )

            # Update slot status to available if it was occupied by this session
            storage_manager.update_slot_status(
                slot_id=session["slot_id"], new_status="available"
            )

        logging.info(f"Deleted parking session {session_id}")

        return {
            "success": True,
            "message": "Session deleted successfully",
            "deleted_session": deleted_session,
        }

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to delete session {session_id}: {str(e)}")
        raise HTTPException(
            status_code=500, detail=f"Failed to delete session: {str(e)}"
        )


@router.put(
    "/update-exit",
    responses={
        200: {
            "description": "Session exit updated successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Session exit updated successfully",
                        "session": {
                            "session_id": "session-uuid-here",
                            "slot_id": "A1",
                            "entrance_id": "E1",
                            "exit_id": "X2",
                            "updated_exit": True,
                        },
                    }
                }
            },
        },
        404: {
            "description": "Session not found",
            "content": {
                "application/json": {"example": {"detail": "Session not found"}}
            },
        },
    },
)
def update_session_exit(
    session_id: str = Query(..., description="Session ID"),
    exit_id: Optional[str] = Query(None, description="Specific exit ID to use"),
    building_name: Optional[str] = Query(
        None, description="Building name for automatic exit calculation"
    ),
    map_id: Optional[str] = Query(
        None, description="Map ID for automatic exit calculation"
    ),
):
    """
    Update the exit_id for an active parking session

    This allows users to change their intended exit during an active parking session.
    You can either specify a specific exit_id or let the system recalculate the nearest exit.
    """
    try:
        # Find the session
        session = session_collection.find_one({"session_id": session_id})
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")

        new_exit_id = exit_id

        # If no specific exit_id provided, calculate nearest exit
        if not new_exit_id and (building_name or map_id):
            try:
                map_data = get_map_data(map_id, building_name)
                if map_data:
                    parking_map = map_data.get("parking_map", [])
                    if parking_map:
                        planner = PathPlanner(parking_map)
                        nearest_exit, distance, path = (
                            planner.find_nearest_exit_to_slot(session["slot_id"])
                        )
                        if nearest_exit:
                            new_exit_id = nearest_exit.get("exit_id")
                            logging.info(
                                f"Recalculated nearest exit {new_exit_id} for session {session_id}"
                            )
            except Exception as e:
                logging.error(f"Error recalculating exit for session {session_id}: {e}")

        if not new_exit_id:
            raise HTTPException(
                status_code=400,
                detail="No exit_id provided and unable to calculate nearest exit",
            )

        # Update the session
        session_collection.update_one(
            {"session_id": session_id}, {"$set": {"exit_id": new_exit_id}}
        )

        # Get updated session
        updated_session = session_collection.find_one({"session_id": session_id})
        updated_session.pop("_id", None)

        logging.info(f"Updated exit_id to {new_exit_id} for session {session_id}")

        return {
            "success": True,
            "message": "Session exit updated successfully",
            "session": {
                "session_id": session_id,
                "slot_id": updated_session["slot_id"],
                "entrance_id": updated_session.get("entrance_id", ""),
                "exit_id": updated_session["exit_id"],
                "updated_exit": True,
            },
        }

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to update session exit: {e}")
        raise HTTPException(status_code=500, detail="Failed to update session exit")
