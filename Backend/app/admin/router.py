from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, EmailStr, Field
from app.database import user_collection, db
from app.parking.storage import storage_manager
from app.auth.auth import AdminEdit, AdminChangePassword, AdminSlotStatusUpdate
from app.auth.utils import hash_password, verify_password
from app.parking.utils import get_map_data, EXAMPLE_MAP_ID
from app.examples.example_map import example_map
import random
import string
import logging
import os
import json
import re
import copy
from typing import Dict, Any, Optional, Union
from app.cloudwatch_metrics import metrics

admin_router = APIRouter(prefix="/admin", tags=["admin"])


class AdminRegisterRequest(BaseModel):
    email: EmailStr
    keyID: str


class AdminLoginRequest(BaseModel):
    keyID: str
    username: str
    password: str
    email: EmailStr


class DataClearRequest(BaseModel):
    admin_password: str  # Admin password for security verification


class DestinationRatesRequest(BaseModel):
    base_rate_per_hour: Optional[str] = Field(
        default="-", description="Base hourly rate (use '-' to keep existing value)"
    )
    peak_hour_surcharge_rate: Optional[str] = Field(
        default="-",
        description="Peak hour surcharge rate (use '-' to keep existing value)",
    )
    weekend_surcharge_rate: Optional[str] = Field(
        default="-",
        description="Weekend surcharge rate (use '-' to keep existing value)",
    )
    public_holiday_surcharge_rate: Optional[str] = Field(
        default="-",
        description="Public holiday surcharge rate (use '-' to keep existing value)",
    )


class AdminEditParkingRateRequest(BaseModel):
    destination: str = Field(..., description="Destination name")
    rates: DestinationRatesRequest
    keyID: str = Field(..., description="Admin keyID for authentication")
    username: str = Field(..., description="Admin username for authentication")
    password: str = Field(..., description="Admin password for authentication")


def generate_username():
    letters = "".join(random.choices(string.ascii_lowercase, k=4))
    digits = "".join(random.choices(string.digits, k=4))
    return letters + digits


def find_slot_by_id_with_context(
    slot_id: str, building_name: str = None, map_id: str = None, level: int = None
) -> Optional[Dict[str, Any]]:
    """
    Find a specific parking slot by slot_id, supporting both example data and database data
    Uses parking module's prioritization logic: database data is prioritized over example data

    Args:
        slot_id: The slot ID to search for
        building_name: Optional building name for context
        map_id: Optional map ID for context
        level: Optional level for context

    Returns:
        Dict containing slot data and map info, or None if not found
        Format: {
            "slot": {slot data},
            "map_id": "analysis_id",
            "building_name": "building name",
            "level": level_number
        }
    """
    try:
        # First try to get map data using the parking module's approach
        map_data = None
        if map_id or building_name:
            try:
                map_data = get_map_data(map_id, building_name)
            except:
                # If get_map_data fails, return None - don't fall back to storage manager alone
                # This ensures we maintain the same prioritization as parking module
                pass

        # If we have map data, search within it
        if map_data:
            for level_data in map_data.get("parking_map", []):
                # Apply level filter if specified
                if level is not None and level_data.get("level") != level:
                    continue

                for slot in level_data.get("slots", []):
                    if slot.get("slot_id") == slot_id:
                        return {
                            "slot": slot,
                            "map_id": map_data.get("_id"),
                            "building_name": map_data.get("building_name"),
                            "level": level_data.get("level"),
                        }

        # If no specific map context provided, search database first, then try example buildings
        if not map_id and not building_name:
            result = storage_manager.find_slot_by_id(slot_id)
            if result:
                return result

            # If not found in database, check example data for common example buildings
            from app.parking.utils import EXAMPLE_BUILDINGS, EXAMPLE_MAP_ID

            for example_building in EXAMPLE_BUILDINGS:
                try:
                    example_data = get_map_data(building_name=example_building)
                    if example_data:
                        for level_data in example_data.get("parking_map", []):
                            for slot in level_data.get("slots", []):
                                if slot.get("slot_id") == slot_id:
                                    return {
                                        "slot": slot,
                                        "map_id": example_data.get("_id"),
                                        "building_name": example_data.get(
                                            "building_name"
                                        ),
                                        "level": level_data.get("level"),
                                    }
                except:
                    continue

        # No slot found
        return None

    except Exception as e:
        logging.error(f"Failed to find slot {slot_id}: {e}")
        return None


def generate_password(length=10):
    # Include at least one uppercase, one lowercase, one digit, one symbol
    if length < 4:
        raise ValueError("Password length must be at least 4")
    chars = (
        random.choice(string.ascii_uppercase)
        + random.choice(string.ascii_lowercase)
        + random.choice(string.digits)
        + random.choice(string.punctuation)
    )
    remaining = "".join(
        random.choices(
            string.ascii_letters + string.digits + string.punctuation, k=length - 4
        )
    )
    password = list(chars + remaining)
    random.shuffle(password)
    return "".join(password)


@admin_router.post(
    "/register",
    responses={
        200: {
            "description": "Admin registered successfully",
            "content": {
                "application/json": {
                    "example": {
                        "msg": "Admin registered successfully",
                        "username": "abcd1234",
                        "password": "P@ssw0rd!2",
                    }
                }
            },
        },
        400: {
            "description": "Registration error (email/keyID taken)",
            "content": {
                "application/json": {
                    "examples": {
                        "EmailRegistered": {
                            "summary": "Email already registered",
                            "value": {"detail": "Email already registered"},
                        }
                    }
                }
            },
        },
    },
)
def register_admin(data: AdminRegisterRequest):
    data.email = data.email.strip().lower()
    logging.info(f"Admin registration attempt for email: {data.email}")

    if user_collection.find_one({"email": data.email}):
        logging.warning(
            f"Admin registration failed - email already registered: {data.email}"
        )
        metrics.record_auth_event("admin_register", False)
        raise HTTPException(status_code=400, detail="Email already registered")

    username = generate_username()
    while user_collection.find_one({"username": username}):
        username = generate_username()

    password = generate_password()

    user_collection.insert_one(
        {
            "email": data.email,
            "username": username,
            "password": password,  # Store unhashed
            "role": "admin",
            "keyID": data.keyID,
        }
    )

    logging.info(
        f"Admin registered successfully: {data.email} with username: {username}"
    )
    metrics.record_auth_event("admin_register", True)
    metrics.increment_counter("AdminOperations", {"operation": "register"})

    return {
        "msg": "Admin registered successfully",
        "username": username,
        "password": password,
    }


@admin_router.get(
    "/list",
    responses={
        200: {
            "description": "List of all admins",
            "content": {
                "application/json": {
                    "example": [
                        {
                            "email": "admin1@example.com",
                            "username": "admin1",
                            "role": "admin",
                        },
                        {
                            "email": "admin2@example.com",
                            "username": "admin2",
                            "role": "admin",
                        },
                    ]
                }
            },
        }
    },
)
def get_admins():
    logging.info("Fetching list of all admins")
    admins = list(user_collection.find({"role": "admin"}, {"_id": 0, "password": 0}))
    logging.info(f"Retrieved {len(admins)} admin accounts")
    metrics.increment_counter("AdminOperations", {"operation": "list_admins"})
    return admins


@admin_router.post(
    "/login",
    responses={
        200: {
            "description": "Admin login successful",
            "content": {
                "application/json": {"example": {"msg": "Admin login successful"}}
            },
        },
        400: {
            "description": "Login error (invalid credentials)",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidKeyID": {
                            "summary": "Invalid keyID",
                            "value": {"detail": "Invalid keyID"},
                        },
                        "WrongUsername": {
                            "summary": "Username does not match keyID",
                            "value": {"detail": "Username does not match keyID"},
                        },
                        "WrongPassword": {
                            "summary": "Incorrect password",
                            "value": {"detail": "Incorrect password"},
                        },
                        "WrongEmail": {
                            "summary": "Email does not match keyID or username",
                            "value": {
                                "detail": "Email does not match keyID or username"
                            },
                        },
                    }
                }
            },
        },
    },
)
def admin_login(credentials: AdminLoginRequest):
    logging.info(
        f"Admin login attempt for keyID: {credentials.keyID}, username: {credentials.username}, email: {credentials.email}"
    )

    # Find admin by both keyID and username (supports multiple admins per keyID)
    admin = user_collection.find_one(
        {
            "keyID": {"$regex": f"^{re.escape(credentials.keyID)}$", "$options": "i"},
            "username": credentials.username,
            "role": "admin",
        }
    )

    if not admin:
        logging.warning(
            f"Admin login failed - no admin found with keyID: {credentials.keyID} and username: {credentials.username}"
        )
        metrics.record_auth_event("admin_login", False)
        raise HTTPException(
            status_code=400, detail="Invalid keyID and username combination"
        )

    # Verify email matches
    if admin["email"].lower() != credentials.email.lower():
        logging.warning(
            f"Admin login failed - email mismatch for keyID/username: {credentials.keyID}"
        )
        metrics.record_auth_event("admin_login", False)
        raise HTTPException(
            status_code=400, detail="Email does not match keyID or username"
        )

    # Handle both plain text (for initally generated password) and hashed passwords
    password_is_hashed = admin["password"].startswith("$2b$")  # bcrypt hash indicator
    if password_is_hashed:
        # Use verify_password for hashed passwords
        if not verify_password(credentials.password, admin["password"]):
            logging.warning(
                f"Admin login failed - incorrect password for keyID: {credentials.keyID}"
            )
            metrics.record_auth_event("admin_login", False)
            raise HTTPException(status_code=400, detail="Incorrect password")
    else:
        # Use direct comparison for plain text passwords (old pw)
        if admin["password"] != credentials.password:
            logging.warning(
                f"Admin login failed - incorrect password for keyID: {credentials.keyID}"
            )
            metrics.record_auth_event("admin_login", False)
            raise HTTPException(status_code=400, detail="Incorrect password")

    logging.info(
        f"Admin login successful for keyID: {credentials.keyID}, email: {credentials.email}"
    )
    metrics.record_auth_event("admin_login", True)
    metrics.increment_counter("AdminOperations", {"operation": "login"})

    return {"msg": "Admin login successful"}


@admin_router.get(
    "/data-stats",
    responses={
        200: {
            "description": "Current system data statistics",
            "content": {
                "application/json": {
                    "example": {
                        "users": {"total": 15, "regular_users": 12, "admins": 3},
                        "parking_maps": {"total": 8, "total_size_mb": 25.4},
                    }
                }
            },
        }
    },
)
def get_data_statistics():
    """
    Get current system data statistics for monitoring before clearing.
    """
    try:
        # Get user statistics
        total_users = user_collection.count_documents({})
        regular_users = user_collection.count_documents({"role": "user"})
        admin_users = user_collection.count_documents({"role": "admin"})

        # Get storage statistics
        storage_stats = storage_manager.get_storage_stats()

        return {
            "users": {
                "total": total_users,
                "regular_users": regular_users,
                "admins": admin_users,
            },
            "parking_maps": {
                "total": storage_stats.get("total_analyses", 0),
                "total_size_mb": storage_stats.get("total_size_mb", 0.0),
            },
        }

    except Exception as e:
        logging.error(f"Failed to get data statistics: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to retrieve data statistics: {str(e)}"
        )


@admin_router.delete(
    "/clear-all-data",
    summary="Clear All Test Data",
    description="⚠️ **DANGER ZONE** ⚠️<br><br>**Required Authentication:**<br>• Admin Password: `123456`<br><br>**Actions Performed:**<br>• Delete all user accounts<br>• Delete all parking analyses<br>• Delete all QR codes<br>• Delete all parking sessions<br>• Preserve image files<br><br>**This operation is irreversible!**",
    responses={
        200: {
            "description": "All test data cleared successfully",
            "content": {
                "application/json": {
                    "example": {
                        "message": "All test data cleared successfully",
                        "cleared_data": {
                            "users_deleted": 5,
                            "maps_deleted": 3,
                            "qrcodes_deleted": 2,
                            "sessions_deleted": 8,
                            "storage_cleared_mb": 15.7,
                        },
                        "note": "User accounts, parking analysis records, QR codes, and parking sessions have been deleted. Image files in app/examples/images are preserved.",
                    }
                }
            },
        },
        401: {
            "description": "Invalid admin password",
            "content": {
                "application/json": {
                    "example": {"detail": "Invalid admin password. Access denied."}
                }
            },
        },
        500: {
            "description": "Internal server error during data clearing",
            "content": {
                "application/json": {
                    "example": {"detail": "Failed to clear data due to internal error"}
                }
            },
        },
    },
)
def clear_all_test_data(request: DataClearRequest):
    """
    Clear all test data from MongoDB (preserving image files).

    **Security Requirements:**
    - Admin password: `123456`

    **This endpoint will:**
    - Delete all user accounts
    - Delete all parking map analyses
    - Delete all QR code records
    - Delete all parking sessions
    - Preserve uploaded images in app/examples/images
    - Reset database to initial state

    **Request Body Example:**
    ```json
    {
        "admin_password": "123456"
    }
    ```

    ⚠️ **WARNING: This action is irreversible for database records!**
    """
    logging.warning("Admin data clear operation requested")

    # Safety check - require admin password
    if request.admin_password != "123456":
        logging.warning("Data clear operation rejected - invalid admin password")
        raise HTTPException(
            status_code=401, detail="Invalid admin password. Access denied."
        )

    try:
        cleared_stats = {
            "users_deleted": 0,
            "maps_deleted": 0,
            "qrcodes_deleted": 0,
            "sessions_deleted": 0,
            "storage_cleared_mb": 0.0,
        }

        # 1. Get storage stats before clearing
        storage_stats = storage_manager.get_storage_stats()
        cleared_stats["storage_cleared_mb"] = storage_stats.get("total_size_mb", 0.0)

        # 2. Clear user collection
        users_result = user_collection.delete_many({})
        cleared_stats["users_deleted"] = users_result.deleted_count
        logging.info(f"Deleted {users_result.deleted_count} user records")

        # 3. Clear maps collection
        maps_collection = db.maps
        maps_result = maps_collection.delete_many({})
        cleared_stats["maps_deleted"] = maps_result.deleted_count
        logging.info(f"Deleted {maps_result.deleted_count} map analysis records")

        # 4. Clear QR codes collection
        qrcodes_collection = db.qrcodes
        qrcodes_result = qrcodes_collection.delete_many({})
        cleared_stats["qrcodes_deleted"] = qrcodes_result.deleted_count
        logging.info(f"Deleted {qrcodes_result.deleted_count} QR code records")

        # 5. Clear parking sessions collection
        sessions_collection = db.sessions
        sessions_result = sessions_collection.delete_many({})
        cleared_stats["sessions_deleted"] = sessions_result.deleted_count
        logging.info(f"Deleted {sessions_result.deleted_count} parking session records")

        # 6. Keep images directory intact (only clear database records)
        # Note: Physical image files in app/examples/images are preserved
        logging.info(
            "Image files in app/examples/images preserved (only database records cleared)"
        )

        # 7. Record metrics
        metrics.increment_counter("AdminOperations", {"operation": "clear_all_data"})

        logging.warning(f"Data clear operation completed successfully: {cleared_stats}")

        return {
            "message": "All test data cleared successfully",
            "cleared_data": cleared_stats,
            "note": "User accounts, parking analysis records, QR codes, and parking sessions have been deleted. Image files in app/examples/images are preserved.",
        }

    except Exception as e:
        logging.error(f"Failed to clear test data: {e}")
        metrics.increment_counter(
            "AdminOperations", {"operation": "clear_all_data_failed"}
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to clear data due to internal error: {str(e)}",
        )


@admin_router.put(
    "/admin_edit_profile",
    responses={
        200: {
            "description": "Admin profile updated successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Profile updated successfully",
                        "admin_info": {
                            "keyID": "Westfield Sydney",
                            "username": "new_admin_user",
                            "email": "admin@example.com",
                        },
                        "changes_summary": {
                            "changed_fields": ["username=new_admin_user"],
                            "preserved_fields": [],
                        },
                    }
                }
            },
        },
        400: {
            "description": "Bad request (empty username, no changes made, or username taken)",
            "content": {
                "application/json": {
                    "examples": {
                        "NoFields": {
                            "summary": "No changes made",
                            "value": {
                                "detail": "New username is the same as current username. No changes made."
                            },
                        },
                        "EmptyUsername": {
                            "summary": "Username cannot be empty",
                            "value": {"detail": "Username cannot be empty."},
                        },
                        "UsernameTaken": {
                            "summary": "Username already taken",
                            "value": {
                                "detail": "Username already taken by another admin."
                            },
                        },
                    }
                }
            },
        },
        401: {
            "description": "Authentication failed",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidKeyID": {
                            "summary": "Invalid keyID",
                            "value": {"detail": "Invalid keyID"},
                        },
                        "WrongUsername": {
                            "summary": "Username does not match keyID",
                            "value": {"detail": "Username does not match keyID"},
                        },
                        "WrongPassword": {
                            "summary": "Incorrect password",
                            "value": {"detail": "Incorrect password"},
                        },
                    }
                }
            },
        },
        404: {
            "description": "Admin not found",
            "content": {"application/json": {"example": {"detail": "Admin not found"}}},
        },
    },
)
def admin_edit_profile(data: AdminEdit):
    """
    Edit admin profile details (username only)

    Allows authenticated administrators to update their username.
    The admin must provide their current credentials for authentication before making changes.
    The new_username field is required and must be provided.
    """
    logging.info(f"Admin profile edit request for keyID: {data.keyID}")

    # Authenticate admin using both keyID and username (supports multiple admins per keyID)
    admin = user_collection.find_one(
        {
            "keyID": {"$regex": f"^{re.escape(data.keyID)}$", "$options": "i"},
            "username": data.current_username,
            "role": "admin",
        }
    )
    if not admin:
        logging.warning(
            f"Admin profile edit failed - no admin found with keyID: {data.keyID} and username: {data.current_username}"
        )
        metrics.record_auth_event("admin_edit_profile", False)
        raise HTTPException(
            status_code=401, detail="Invalid keyID and username combination"
        )

    # Verify current password (handle both plain text and hashed passwords)
    password_is_hashed = admin["password"].startswith("$2b$")  # bcrypt hash indicator
    if password_is_hashed:
        # Use verify_password for hashed passwords
        if not verify_password(data.current_password, admin["password"]):
            logging.warning(
                f"Admin profile edit failed - incorrect password for keyID: {data.keyID}"
            )
            metrics.record_auth_event("admin_edit_profile", False)
            raise HTTPException(status_code=401, detail="Incorrect password")
    else:
        # Use direct comparison for plain text passwords (old pw)
        if admin["password"] != data.current_password:
            logging.warning(
                f"Admin profile edit failed - incorrect password for keyID: {data.keyID}"
            )
            metrics.record_auth_event("admin_edit_profile", False)
            raise HTTPException(status_code=401, detail="Incorrect password")

    # Verify admin role
    if admin.get("role") != "admin":
        logging.warning(f"Profile edit failed - user {data.keyID} is not an admin")
        metrics.record_auth_event("admin_edit_profile", False)
        raise HTTPException(
            status_code=401, detail="Access denied. Admin role required."
        )

    # Collect fields to update
    update_fields = {}
    updated_field_names = []
    preserved_field_names = []

    # Handle username update (new_username is required)
    new_username = data.new_username.strip()

    # Validate new username is not empty
    if not new_username:
        raise HTTPException(status_code=400, detail="Username cannot be empty.")

    # Check if new username is different from current
    if new_username != admin["username"]:
        # check if username is taken by another admin (considering multiple admins can share keyID)
        existing_admin = user_collection.find_one(
            {
                "username": new_username,
                "role": "admin",
                "$or": [
                    {"keyID": {"$ne": admin["keyID"]}},  # Different keyID
                    {
                        "email": {"$ne": admin["email"]}
                    },  # Same keyID but different admin (different email)
                ],
            }
        )
        if existing_admin:
            raise HTTPException(
                status_code=400, detail="Username already taken by another admin."
            )

        update_fields["username"] = new_username
        updated_field_names.append(f"username={new_username}")
    else:
        # Username is the same as current, no update needed
        preserved_field_names.append(f"username={admin['username']}")

    # Check if at least one field is being updated
    if not update_fields:
        raise HTTPException(
            status_code=400,
            detail="New username is the same as current username. No changes made.",
        )

    # Update the admin profile
    user_collection.update_one({"keyID": admin["keyID"]}, {"$set": update_fields})

    # Record successful edit
    metrics.record_auth_event("admin_edit_profile", True)
    metrics.increment_counter("AdminOperations", {"operation": "edit_profile"})

    logging.info(
        f"Admin profile updated successfully for keyID: {data.keyID}, fields: {updated_field_names}"
    )

    return {
        "success": True,
        "message": "Profile updated successfully",
        "admin_info": {
            "keyID": admin["keyID"],
            "username": update_fields.get("username", admin["username"]),
            "email": admin["email"],
        },
        "changes_summary": {
            "changed_fields": (
                updated_field_names if updated_field_names else ["No fields changed"]
            ),
            "preserved_fields": (
                preserved_field_names
                if preserved_field_names
                else ["No fields preserved"]
            ),
        },
    }


@admin_router.put(
    "/admin_change_password",
    responses={
        200: {
            "description": "Admin password changed successfully",
            "content": {
                "application/json": {
                    "example": {"msg": "Password changed successfully."}
                }
            },
        },
        401: {
            "description": "Authentication failed",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidKeyID": {
                            "summary": "Invalid keyID",
                            "value": {"detail": "Invalid keyID"},
                        },
                        "WrongUsername": {
                            "summary": "Username does not match keyID",
                            "value": {"detail": "Username does not match keyID"},
                        },
                        "WrongPassword": {
                            "summary": "Current password is incorrect",
                            "value": {"detail": "Current password is incorrect."},
                        },
                    }
                }
            },
        },
        400: {
            "description": "Bad request (password mismatch or weak password)",
            "content": {
                "application/json": {
                    "examples": {
                        "PasswordMismatch": {
                            "summary": "New password and confirmation do not match",
                            "value": {
                                "detail": "New password and confirmation do not match."
                            },
                        },
                        "PasswordTooShort": {
                            "summary": "Too short",
                            "value": {
                                "detail": "Password must be at least 8 characters long"
                            },
                        },
                        "PasswordNoNumber": {
                            "summary": "Missing number",
                            "value": {
                                "detail": "Password must contain at least one number"
                            },
                        },
                        "PasswordNoSpecial": {
                            "summary": "Missing special character",
                            "value": {
                                "detail": "Password must contain at least one special character"
                            },
                        },
                        "PasswordTooCommon": {
                            "summary": "Too common",
                            "value": {
                                "detail": "Password is too common. Please choose a more secure one."
                            },
                        },
                        "PasswordSameAsCurrent": {
                            "summary": "Same as current",
                            "value": {
                                "detail": "New password cannot be the same as the current password."
                            },
                        },
                    }
                }
            },
        },
        404: {
            "description": "Admin not found",
            "content": {"application/json": {"example": {"detail": "Admin not found"}}},
        },
    },
)
def admin_change_password(data: AdminChangePassword):
    """
    Change admin password

    Allows authenticated administrators to change their password.
    The admin must provide their current credentials for authentication before making changes.
    All password fields are required for this operation.
    """
    logging.info(f"Admin password change request for keyID: {data.keyID}")

    # Authenticate admin using keyID AND username (supports multiple admins per keyID)
    admin = user_collection.find_one(
        {
            "keyID": {"$regex": f"^{re.escape(data.keyID)}$", "$options": "i"},
            "username": data.current_username,
            "role": "admin",
        }
    )
    if not admin:
        logging.warning(
            f"Admin password change failed - no admin found with keyID: {data.keyID} and username: {data.current_username}"
        )
        metrics.record_auth_event("admin_change_password", False)
        raise HTTPException(
            status_code=401, detail="Invalid keyID and username combination"
        )

    # Verify current password (handle both plain text and hashed passwords)
    password_is_hashed = admin["password"].startswith("$2b$")  # bcrypt hash indicator
    if password_is_hashed:
        # Use verify_password for hashed passwords
        if not verify_password(data.current_password, admin["password"]):
            logging.warning(
                f"Admin password change failed - incorrect password for keyID: {data.keyID}"
            )
            metrics.record_auth_event("admin_change_password", False)
            raise HTTPException(
                status_code=401, detail="Current password is incorrect."
            )
    else:
        # Use direct comparison for plain text passwords (old pw)
        if admin["password"] != data.current_password:
            logging.warning(
                f"Admin password change failed - incorrect password for keyID: {data.keyID}"
            )
            metrics.record_auth_event("admin_change_password", False)
            raise HTTPException(
                status_code=401, detail="Current password is incorrect."
            )

    # Verify admin role
    if admin.get("role") != "admin":
        logging.warning(f"Password change failed - user {data.keyID} is not an admin")
        metrics.record_auth_event("admin_change_password", False)
        raise HTTPException(
            status_code=401, detail="Access denied. Admin role required."
        )

    # Validate new password and confirmation match
    if data.new_password != data.confirm_new_password:
        raise HTTPException(
            status_code=400, detail="New password and confirmation do not match."
        )

    # Check new password is different from current
    if data.new_password == data.current_password:
        raise HTTPException(
            status_code=400,
            detail="New password cannot be the same as the current password.",
        )

    # Password strength validation
    if len(data.new_password) < 8:
        raise HTTPException(
            status_code=400, detail="Password must be at least 8 characters long"
        )

    if not re.search(r"\d", data.new_password):
        raise HTTPException(
            status_code=400, detail="Password must contain at least one number"
        )

    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", data.new_password):
        raise HTTPException(
            status_code=400,
            detail="Password must contain at least one special character",
        )

    # Check against common passwords
    COMMON_PASSWORDS = {"123456", "123456789", "qwerty", "password", "12345678"}
    for common in COMMON_PASSWORDS:
        if common in data.new_password.lower():
            raise HTTPException(
                status_code=400,
                detail="Password is too common. Please choose a more secure one.",
            )

    # Update password
    hashed_pw = hash_password(data.new_password)
    user_collection.update_one(
        {"keyID": admin["keyID"]}, {"$set": {"password": hashed_pw}}
    )

    # Record successful password change
    metrics.record_auth_event("admin_change_password", True)
    metrics.increment_counter("AdminOperations", {"operation": "change_password"})

    logging.info(f"Admin password changed successfully for keyID: {data.keyID}")

    return {"msg": "Password changed successfully."}


def save_parking_rates(rates_config: Dict[str, Any]) -> bool:
    # Saves updated parking rates configuration to MongoDB
    try:
        from app.parking.utils import save_parking_rates_to_mongodb

        # Save to MongoDB
        result = save_parking_rates_to_mongodb(rates_config)

        if result:
            logging.info(f"Parking rates configuration saved successfully to MongoDB")
        else:
            logging.error(f"Failed to save parking rates configuration to MongoDB")

        return result

    except Exception as e:
        logging.error(f"Failed to save parking rates configuration: {e}")
        return False


def parse_rate_value(
    rate_str: str, field_name: str, existing_value: float = 0.0
) -> float:
    # Parse rate value from string, handling "-" as "keep existing value"

    # Args:
    #     rate_str: Rate value as string ("-" means keep existing)
    #     field_name: Field name for error messages
    #     existing_value: Current value to keep if rate_str is "-"

    # Returns:
    #     float: Parsed rate value

    # Raises:
    #     ValueError: If rate_str is not a valid number or "-"
    if rate_str == "-":
        return existing_value

    try:
        parsed_value = float(rate_str)
        if parsed_value < 0:
            raise ValueError(f"{field_name} must be non-negative (got {parsed_value})")
        return parsed_value
    except (ValueError, TypeError) as e:
        if "could not convert" in str(e).lower():
            raise ValueError(
                f"{field_name} must be a valid number or '-' (got '{rate_str}')"
            )
        raise


def normalize_destination_name(destination: str) -> str:
    # Normalize destination name to consistent title case format

    # Examples:
    #     "westfield sydney" -> "Westfield Sydney"
    #     "WESTFIELD BONDI JUNCTION" -> "Westfield Bondi Junction"
    #     "westfield_parramatta" -> "Westfield Parramatta"

    # Strip whitespace and replace underscores/hyphens with spaces
    normalized = destination.strip().replace("_", " ").replace("-", " ")

    # Convert to title case (first letter of each word capitalized)
    normalized = " ".join(word.capitalize() for word in normalized.split())

    return normalized


def is_admin_authorized_for_destination(keyID: str, destination: str) -> bool:
    # Check if an admin is authorized to edit parking rates for a specific destination
    # based on their keyID. Both keyID and destination matching is case insensitive.

    # Handle empty keyID
    if not keyID or not keyID.strip():
        return False

    # Normalize both strings for comparison
    normalized_keyid = keyID.lower().replace("_", " ").replace("-", " ")
    normalized_destination = destination.lower()

    # Check if keyID is contained in destination or vice versa
    # This allows flexible matching patterns
    if (
        normalized_keyid in normalized_destination
        or normalized_destination in normalized_keyid
    ):
        return True

    # Check for word-by-word matching (e.g., "westfield sydney" matches "Westfield Sydney")
    keyid_words = set(normalized_keyid.split())
    destination_words = set(normalized_destination.split())

    # If at least 2 words match or all keyID words are in destination, allow access
    common_words = keyid_words.intersection(destination_words)
    if len(common_words) >= 2 or (
        keyid_words and keyid_words.issubset(destination_words)
    ):
        return True

    return False


@admin_router.post(
    "/admin_edit_parking_rate",
    responses={
        200: {
            "description": "Parking rates updated successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Parking rates updated successfully for Westfield Sydney",
                        "destination": "Westfield Sydney",
                        "updated_by": "admin_user",
                        "updated_rates": {
                            "base_rate_per_hour": 8.0,
                            "peak_hour_surcharge_rate": 0.6,
                            "weekend_surcharge_rate": 0.4,
                            "public_holiday_surcharge_rate": 1.2,
                        },
                        "changes_summary": {
                            "changed_fields": [
                                "base_rate_per_hour=8.0",
                                "public_holiday_surcharge_rate=1.2",
                            ],
                            "preserved_fields": [
                                "peak_hour_surcharge_rate=0.6",
                                "weekend_surcharge_rate=0.4",
                            ],
                        },
                    }
                }
            },
        },
        400: {
            "description": "Invalid input data or validation error",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidDestination": {
                            "summary": "Empty destination name",
                            "value": {"detail": "Destination name cannot be empty"},
                        },
                        "InvalidRateFormat": {
                            "summary": "Invalid rate format",
                            "value": {
                                "detail": "base_rate_per_hour must be a valid number or '-' (got 'abc')"
                            },
                        },
                        "NegativeRate": {
                            "summary": "Negative rate value",
                            "value": {
                                "detail": "peak_hour_surcharge_rate must be non-negative (got -0.5)"
                            },
                        },
                    }
                }
            },
        },
        401: {
            "description": "Invalid admin credentials",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidKeyID": {
                            "summary": "Invalid keyID",
                            "value": {"detail": "Invalid keyID"},
                        },
                        "WrongUsername": {
                            "summary": "Username does not match keyID",
                            "value": {"detail": "Username does not match keyID"},
                        },
                        "WrongPassword": {
                            "summary": "Incorrect password",
                            "value": {"detail": "Incorrect password"},
                        },
                    }
                }
            },
        },
        403: {
            "description": "Access denied - admin not authorized for this destination",
            "content": {
                "application/json": {
                    "example": {
                        "detail": "Access denied. Your keyID does not authorize you to edit rates for this destination."
                    }
                }
            },
        },
        500: {
            "description": "Internal server error during rate update",
            "content": {
                "application/json": {
                    "example": {
                        "detail": "Failed to update parking rates due to internal error"
                    }
                }
            },
        },
    },
)
def admin_edit_parking_rate(request: AdminEditParkingRateRequest):
    """
    Edit parking rates for a specific destination

    This feature allows authenticated administrators/operators to update parking rates for destinations
    they are authorized to manage. Admins can only edit rates for destinations that match their keyID.
    If the destination doesn't exist, it will be created with the provided rates.

    **Case Insensitive Matching:**
    - Both keyID and destination names are handled case insensitively
    - e.g. "westfield sydney", "WESTFIELD SYDNEY", "Westfield_Sydney" all work the same

    **Rate Field Behavior:**
    - All rate fields are optional with default value "-"
    - Use "-" to keep the existing value unchanged
    - Provide a number to update that specific field
    - Only modified fields are updated, others will preserve their current values

    **Authorization Requirements:**
    - Admin's keyID must match or be related to the destination name
    - Case-insensitive matching with flexible patterns
    - e.g. keyID "westfield_sydney" can edit "Westfield Sydney" (provided this keyID exists)

    **Note: Changes take effect immediately and will affect all future fare predictions**
    """

    logging.info(
        f"Admin parking rate edit request for destination: {request.destination} by keyID: {request.keyID}"
    )

    # Authenticate admin using both keyID and username (fixed - to allow multiple admins per keyID)
    admin = user_collection.find_one(
        {
            "keyID": {"$regex": f"^{re.escape(request.keyID)}$", "$options": "i"},
            "username": request.username,
            "role": "admin",
        }
    )
    if not admin:
        logging.warning(
            f"Parking rate edit failed - no admin found with keyID: {request.keyID} and username: {request.username}"
        )
        metrics.record_auth_event("admin_edit_parking_rate", False)
        raise HTTPException(
            status_code=401, detail="Invalid keyID and username combination"
        )

    # Verify current password (handle both plain text and hashed passwords)
    password_is_hashed = admin["password"].startswith("$2b$")  # bcrypt hash indicator
    if password_is_hashed:
        # Use verify_password for hashed passwords
        if not verify_password(request.password, admin["password"]):
            logging.warning(
                f"Parking rate edit failed - incorrect password for keyID: {request.keyID}"
            )
            metrics.record_auth_event("admin_edit_parking_rate", False)
            raise HTTPException(status_code=401, detail="Incorrect password")
    else:
        # Use direct comparison for plain text passwords (old pw)
        if admin["password"] != request.password:
            logging.warning(
                f"Parking rate edit failed - incorrect password for keyID: {request.keyID}"
            )
            metrics.record_auth_event("admin_edit_parking_rate", False)
            raise HTTPException(status_code=401, detail="Incorrect password")

    # Verify admin role
    if admin.get("role") != "admin":
        logging.warning(
            f"Parking rate edit failed - user {request.keyID} is not an admin"
        )
        metrics.record_auth_event("admin_edit_parking_rate", False)
        raise HTTPException(
            status_code=401, detail="Access denied. Admin role required."
        )

    # Validate and normalize destination name
    destination = normalize_destination_name(request.destination)
    if not destination:
        raise HTTPException(status_code=400, detail="Destination name cannot be empty")

    # Check if admin is authorized to edit this specific destination
    if not is_admin_authorized_for_destination(request.keyID, destination):
        logging.warning(
            f"Parking rate edit failed - admin {request.keyID} not authorized for destination: {destination}"
        )
        metrics.record_auth_event("admin_edit_parking_rate", False)
        raise HTTPException(
            status_code=403,
            detail="Access denied. Your keyID does not authorize you to edit rates for this destination.",
        )

    try:
        # Load current parking rates configuration
        from app.parking.utils import load_parking_rates

        rates_config = load_parking_rates()

        # Log what we're preserving
        preserved_config = {
            "currency": rates_config.get("currency"),
            "default_rates": rates_config.get("default_rates"),
            "peak_hours": rates_config.get("peak_hours"),
            "public_holidays_count": len(rates_config.get("public_holidays", [])),
            "existing_destinations_count": len(rates_config.get("destinations", {})),
        }
        logging.info(f"Preserving existing configuration: {preserved_config}")

        # Store the previous rates for this destination (if exists) for logging
        previous_rates = None
        existing_rates = {}

        if (
            "destinations" in rates_config
            and destination in rates_config["destinations"]
        ):
            previous_rates = rates_config["destinations"][destination].copy()
            existing_rates = previous_rates.copy()
        else:
            # Use default rates if destination doesn't exist
            existing_rates = rates_config.get(
                "default_rates",
                {
                    "base_rate_per_hour": 0.0,
                    "peak_hour_surcharge_rate": 0.0,
                    "weekend_surcharge_rate": 0.0,
                    "public_holiday_surcharge_rate": 0.0,
                },
            )

        # Initialize destinations section if it doesn't exist
        if "destinations" not in rates_config:
            rates_config["destinations"] = {}
            logging.info("Created new 'destinations' section in configuration")

        # Parse and validate each rate field, only updating those that are not "-"
        try:
            new_rates = {
                "base_rate_per_hour": parse_rate_value(
                    request.rates.base_rate_per_hour,
                    "base_rate_per_hour",
                    existing_rates.get("base_rate_per_hour", 0.0),
                ),
                "peak_hour_surcharge_rate": parse_rate_value(
                    request.rates.peak_hour_surcharge_rate,
                    "peak_hour_surcharge_rate",
                    existing_rates.get("peak_hour_surcharge_rate", 0.0),
                ),
                "weekend_surcharge_rate": parse_rate_value(
                    request.rates.weekend_surcharge_rate,
                    "weekend_surcharge_rate",
                    existing_rates.get("weekend_surcharge_rate", 0.0),
                ),
                "public_holiday_surcharge_rate": parse_rate_value(
                    request.rates.public_holiday_surcharge_rate,
                    "public_holiday_surcharge_rate",
                    existing_rates.get("public_holiday_surcharge_rate", 0.0),
                ),
            }
        except ValueError as e:
            logging.warning(f"Rate validation failed for {destination}: {e}")
            raise HTTPException(status_code=400, detail=str(e))

        # Update ONLY the rate values for the specific destination
        # This preserves all other configuration intact
        rates_config["destinations"][destination] = new_rates

        # Log which fields were actually changed vs. kept
        changed_fields = []
        kept_fields = []

        for field_name in [
            "base_rate_per_hour",
            "peak_hour_surcharge_rate",
            "weekend_surcharge_rate",
            "public_holiday_surcharge_rate",
        ]:
            field_value = getattr(request.rates, field_name)
            if field_value != "-":
                changed_fields.append(f"{field_name}={field_value}")
            else:
                kept_fields.append(
                    f"{field_name}={existing_rates.get(field_name, 0.0)}"
                )

        if changed_fields:
            logging.info(
                f"Changed fields for {destination}: {', '.join(changed_fields)}"
            )
        if kept_fields:
            logging.info(
                f"Preserved fields for {destination}: {', '.join(kept_fields)}"
            )

        # Validate that we haven't accidentally modified other parts of the config
        post_update_validation = {
            "currency": rates_config.get("currency"),
            "default_rates": rates_config.get("default_rates"),
            "peak_hours": rates_config.get("peak_hours"),
            "public_holidays_count": len(rates_config.get("public_holidays", [])),
            "destinations_count": len(rates_config.get("destinations", {})),
        }

        # Ensure critical structure is preserved
        if (
            preserved_config["currency"] != post_update_validation["currency"]
            or preserved_config["default_rates"]
            != post_update_validation["default_rates"]
            or preserved_config["peak_hours"] != post_update_validation["peak_hours"]
            or preserved_config["public_holidays_count"]
            != post_update_validation["public_holidays_count"]
        ):

            logging.error(
                "Configuration validation failed - critical structure was modified!"
            )
            raise HTTPException(
                status_code=500,
                detail="Configuration validation failed - unable to preserve existing settings",
            )

        # Log the changes being made
        if previous_rates:
            logging.info(
                f"Updating existing rates for {destination}: {previous_rates} → {rates_config['destinations'][destination]}"
            )
        else:
            logging.info(
                f"Creating new rates for {destination}: {rates_config['destinations'][destination]}"
            )

        # Save updated configuration
        if not save_parking_rates(rates_config):
            raise HTTPException(
                status_code=500,
                detail="Failed to save updated parking rates configuration",
            )

        # Record successful authentication and operation
        metrics.record_auth_event("admin_edit_parking_rate", True)
        metrics.increment_counter("AdminOperations", {"operation": "edit_parking_rate"})

        logging.info(
            f"Parking rates updated successfully for destination: {destination} by admin: {request.username}"
        )

        return {
            "success": True,
            "message": f"Parking rates updated successfully for {destination}",
            "destination": destination,
            "updated_by": request.username,
            "updated_rates": new_rates,
            "changes_summary": {
                "changed_fields": (
                    changed_fields if changed_fields else ["No fields changed"]
                ),
                "preserved_fields": (
                    kept_fields if kept_fields else ["No fields preserved"]
                ),
            },
        }

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to update parking rates for {destination}: {e}")
        metrics.increment_counter(
            "AdminOperations", {"operation": "edit_parking_rate_failed"}
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update parking rates due to internal error: {str(e)}",
        )


@admin_router.get(
    "/parking/slot/info",
    responses={
        200: {
            "description": "Parking slot information retrieved successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "building_name": "Westfield Sydney",
                        "map_id": "uuid-here",
                        "level_filter": 1,
                        "slots": [
                            {
                                "slot_id": "1A",
                                "status": "occupied",
                                "x": 100,
                                "y": 150,
                                "level": 1,
                                "vehicle_id": "ABC123",
                                "reserved_by": "johndoe123",
                            }
                        ],
                    }
                }
            },
        },
        400: {
            "description": "Invalid parameters or slot not found in specified context",
            "content": {
                "application/json": {
                    "example": {
                        "detail": "Slot '1A' found but not in the specified building 'Westfield Bondi'. Actual context: building='Westfield Sydney', map_id='674a1b2c3d4e5f6g7h8i9j0k', level=1"
                    }
                }
            },
        },
        401: {
            "description": "Authentication failed",
            "content": {
                "application/json": {
                    "examples": {
                        "invalid_keyID": {
                            "summary": "Invalid keyID",
                            "value": {"detail": "Invalid keyID"},
                        },
                        "username_mismatch": {
                            "summary": "Username mismatch",
                            "value": {"detail": "Username does not match keyID"},
                        },
                        "incorrect_password": {
                            "summary": "Incorrect password",
                            "value": {"detail": "Incorrect password"},
                        },
                        "access_denied": {
                            "summary": "Not an admin",
                            "value": {"detail": "Access denied. Admin role required."},
                        },
                    }
                }
            },
        },
        404: {
            "description": "Parking slot not found",
            "content": {
                "application/json": {"example": {"detail": "Parking slot not found"}}
            },
        },
        500: {
            "description": "Internal server error",
            "content": {
                "application/json": {
                    "example": {
                        "detail": "Failed to retrieve slot information: Database connection error"
                    }
                }
            },
        },
    },
)
def get_parking_slot_info(
    slot_id: str,
    keyID: str,
    username: str,
    password: str,
    building_name: Optional[str] = None,
    map_id: Optional[str] = None,
    level: Optional[int] = None,
):
    """
    **Admin Only**: Get detailed information about a specific parking slot

    This feature allows administrators to retrieve comprehensive information about any parking slot,
    including its current status, occupancy details, and location information.
    """
    logging.info(f"Admin slot info request for slot: {slot_id} by keyID: {keyID}")

    # Authenticate admin using both keyID and username (multiple admins per keyID)
    admin = user_collection.find_one(
        {
            "keyID": {"$regex": f"^{re.escape(keyID)}$", "$options": "i"},
            "username": username,
            "role": "admin",
        }
    )
    if not admin:
        logging.warning(
            f"Admin slot info failed - no admin found with keyID: {keyID} and username: {username}"
        )
        metrics.record_auth_event("admin_get_slot_info", False)
        raise HTTPException(
            status_code=401, detail="Invalid keyID and username combination"
        )

    # Verify current password (handle both plain text and hashed passwords)
    password_is_hashed = admin["password"].startswith("$2b$")
    if password_is_hashed:
        # Use verify_password for hashed passwords
        if not verify_password(password, admin["password"]):
            logging.warning(
                f"Admin slot info failed - incorrect password for keyID: {keyID}"
            )
            metrics.record_auth_event("admin_get_slot_info", False)
            raise HTTPException(status_code=401, detail="Incorrect password")
    else:
        # Use direct comparison for plain text passwords (old pw)
        if admin["password"] != password:
            logging.warning(
                f"Admin slot info failed - incorrect password for keyID: {keyID}"
            )
            metrics.record_auth_event("admin_get_slot_info", False)
            raise HTTPException(status_code=401, detail="Incorrect password")

    # Verify admin role
    if admin.get("role") != "admin":
        logging.warning(f"Slot info failed - user {keyID} is not an admin")
        metrics.record_auth_event("admin_get_slot_info", False)
        raise HTTPException(
            status_code=401, detail="Access denied. Admin role required."
        )

    metrics.record_auth_event("admin_get_slot_info", True)

    try:
        current_slot_info = None

        # If map_id is provided, search by map_id first
        if map_id:
            current_slot_info = find_slot_by_id_with_context(
                slot_id,
                None,  # Don't provide building_name to avoid example data confusion
                map_id,
                level,
            )

        # If not found by map_id or no map_id provided, try database-first search
        if not current_slot_info:
            # Try database-only search first (no building name to avoid example data)
            db_result = storage_manager.find_slot_by_id(slot_id)
            logging.info(
                f"Database search for slot {slot_id}: {'Found' if db_result else 'Not found'}"
            )
            if db_result:
                logging.info(
                    f"DB result - building: {db_result['building_name']}, map_id: {db_result['map_id']}, status: {db_result['slot']['status']}"
                )
                # Validate context if provided
                context_matches = True
                if (
                    building_name
                    and db_result["building_name"].lower() != building_name.lower()
                ):
                    context_matches = False
                    logging.info(
                        f"Building name mismatch: request={building_name}, db={db_result['building_name']}"
                    )
                if map_id and db_result["map_id"] != map_id:
                    context_matches = False
                    logging.info(
                        f"Map ID mismatch: request={map_id}, db={db_result['map_id']}"
                    )
                if level is not None and db_result["level"] != level:
                    context_matches = False
                    logging.info(
                        f"Level mismatch: request={level}, db={db_result['level']}"
                    )

                if context_matches:
                    current_slot_info = db_result
                    logging.info(
                        f"Using database data - slot status: {current_slot_info['slot']['status']}"
                    )
                else:
                    logging.info(
                        "Database result doesn't match context, will try context search"
                    )

        # If still not found, fall back to context search (which might find example data)
        if not current_slot_info:
            logging.info(
                "No database result, trying context search (may find example data)"
            )
            current_slot_info = find_slot_by_id_with_context(
                slot_id, building_name, map_id, level
            )
            if current_slot_info:
                logging.info(
                    f"Context search result - building: {current_slot_info['building_name']}, map_id: {current_slot_info['map_id']}, status: {current_slot_info['slot']['status']}"
                )
            else:
                logging.warning(f"No slot found in context search either")

        if not current_slot_info:
            logging.warning(f"Slot {slot_id} not found")
            raise HTTPException(status_code=404, detail="Parking slot not found")

        # Validate context if provided
        context_matches = True
        context_errors = []

        if building_name:
            if current_slot_info["building_name"].lower() != building_name.lower():
                context_matches = False
                context_errors.append(f"building '{building_name}'")

        if map_id:
            if current_slot_info["map_id"] != map_id:
                context_matches = False
                context_errors.append(f"map_id '{map_id}'")

        if level is not None:
            if current_slot_info["level"] != level:
                context_matches = False
                context_errors.append(f"level {level}")

        if not context_matches:
            error_msg = (
                f"Slot '{slot_id}' found but not in the specified {', '.join(context_errors)}. "
                f"Actual context: building='{current_slot_info['building_name']}', "
                f"map_id='{current_slot_info['map_id']}', level={current_slot_info['level']}"
            )
            logging.warning(error_msg)
            raise HTTPException(status_code=400, detail=error_msg)

        slot_data = current_slot_info["slot"]

        # Determine data source
        data_source = (
            "example" if current_slot_info["map_id"] == EXAMPLE_MAP_ID else "database"
        )

        logging.info(
            f"Successfully retrieved slot info for {slot_id} from {data_source}"
        )

        response = {
            "success": True,
            "building_name": current_slot_info["building_name"],
            "map_id": current_slot_info["map_id"],
            "level_filter": level,
            "slots": [slot_data],
        }

        return response

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to retrieve slot info for {slot_id}: {e}")
        raise HTTPException(
            status_code=500, detail=f"Failed to retrieve slot information: {str(e)}"
        )


@admin_router.put(
    "/parking/slot/update",
    responses={
        200: {
            "description": "Parking slot updated successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Parking slot status updated successfully",
                        "slot_id": "1A",
                        "old_status": "available",
                        "new_status": "occupied",
                        "updated_by": "admin_user",
                        "building_name": "Westfield Sydney",
                        "map_id": "uuid-here",
                        "level": 1,
                        "vehicle_id": "ABC123",
                        "reserved_by": "johndoe123",
                        "converted_from_example": False,
                        "context_validated": {
                            "building_name": "Westfield Sydney",
                            "map_id": "uuid-here",
                            "level": 1,
                        },
                    }
                }
            },
        },
        201: {
            "description": "Parking slot updated to allocated status (with vehicle)",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Parking slot status updated successfully",
                        "slot_id": "1A",
                        "old_status": "available",
                        "new_status": "allocated",
                        "updated_by": "admin_user",
                        "building_name": "Westfield Sydney",
                        "map_id": "uuid-here",
                        "level": 1,
                        "vehicle_id": "NSW123XYZ",
                        "reserved_by": "johndoe123",
                        "converted_from_example": False,
                        "context_validated": {
                            "building_name": "Westfield Sydney",
                            "map_id": "uuid-here",
                            "level": 1,
                        },
                    }
                }
            },
        },
        400: {
            "description": "Invalid status or request data",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidStatus": {
                            "summary": "Invalid status",
                            "value": {
                                "detail": "Status must be one of: available, occupied, allocated"
                            },
                        },
                        "OccupiedByRequired": {
                            "summary": "reserved_by required for occupied/allocated status",
                            "value": {
                                "detail": "reserved_by is required when status is 'occupied'"
                            },
                        },
                        "InvalidUsername": {
                            "summary": "Invalid username",
                            "value": {
                                "detail": "Username 'invalid_user' not found or is not a valid user"
                            },
                        },
                        "SlotNotFoundInContext": {
                            "summary": "Slot not found in specified context",
                            "value": {
                                "detail": "Slot '1A' not found in the specified building/map/level"
                            },
                        },
                        "ContextMismatch": {
                            "summary": "Slot exists but context doesn't match",
                            "value": {
                                "detail": "Slot '1A' found but not in the specified building 'Westfield Sydney' at level 1"
                            },
                        },
                        "NoContext": {
                            "summary": "No context provided for validation",
                            "value": {
                                "detail": "At least one of building_name, map_id, or level must be provided for context validation"
                            },
                        },
                        "ConversionFailed": {
                            "summary": "Failed to convert example data",
                            "value": {
                                "detail": "Failed to convert example data to database for updating: Database connection error"
                            },
                        },
                    }
                }
            },
        },
        401: {
            "description": "Authentication failed",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidKeyID": {
                            "summary": "Invalid keyID",
                            "value": {"detail": "Invalid keyID"},
                        },
                        "WrongUsername": {
                            "summary": "Username does not match keyID",
                            "value": {"detail": "Username does not match keyID"},
                        },
                        "WrongPassword": {
                            "summary": "Incorrect password",
                            "value": {"detail": "Incorrect password"},
                        },
                    }
                }
            },
        },
        404: {
            "description": "Slot not found",
            "content": {
                "application/json": {"example": {"detail": "Parking slot not found"}}
            },
        },
    },
)
def update_parking_slot_status(request: AdminSlotStatusUpdate):
    """
    Update parking slot status and related information

    Allows authenticated administrators to change parking slot status between
    free, occupied, and allocated states. Also handles vehicle_id and reserved_by fields.
    """
    logging.info(
        f"Admin slot update request for slot: {request.slot_id} to status: {request.new_status} by keyID: {request.keyID}"
    )

    # Authenticate admin using both keyID and username (multiple admins per keyID)
    admin = user_collection.find_one(
        {
            "keyID": {"$regex": f"^{re.escape(request.keyID)}$", "$options": "i"},
            "username": request.username,
            "role": "admin",
        }
    )
    if not admin:
        logging.warning(
            f"Admin slot update failed - no admin found with keyID: {request.keyID} and username: {request.username}"
        )
        metrics.record_auth_event("admin_update_slot_status", False)
        raise HTTPException(
            status_code=401, detail="Invalid keyID and username combination"
        )

    # Verify current password (handle both plain text and hashed passwords)
    password_is_hashed = admin["password"].startswith("$2b$")
    if password_is_hashed:
        # Use verify_password for hashed passwords
        if not verify_password(request.password, admin["password"]):
            logging.warning(
                f"Admin slot update failed - incorrect password for keyID: {request.keyID}"
            )
            metrics.record_auth_event("admin_update_slot_status", False)
            raise HTTPException(status_code=401, detail="Incorrect password")
    else:
        # Use direct comparison for plain text passwords (old pw)
        if admin["password"] != request.password:
            logging.warning(
                f"Admin slot update failed - incorrect password for keyID: {request.keyID}"
            )
            metrics.record_auth_event("admin_update_slot_status", False)
            raise HTTPException(status_code=401, detail="Incorrect password")

    # Verify admin role
    if admin.get("role") != "admin":
        logging.warning(f"Slot update failed - user {request.keyID} is not an admin")
        metrics.record_auth_event("admin_update_slot_status", False)
        raise HTTPException(
            status_code=401, detail="Access denied. Admin role required."
        )

    metrics.record_auth_event("admin_update_slot_status", True)

    try:
        # Validate context parameters - at least one should be provided for proper validation
        has_context = any(
            [request.building_name, request.map_id, request.level is not None]
        )
        if not has_context:
            logging.warning(f"No context provided for slot update: {request.slot_id}")
            raise HTTPException(
                status_code=400,
                detail="At least one of building_name, map_id, or level must be provided for validation",
            )

        # First get current slot info using our enhanced slot finding
        # Try to find in database first, then fall back to context search
        current_slot_info = None

        # If map_id is provided, search by map_id first (most specific)
        if request.map_id:
            current_slot_info = find_slot_by_id_with_context(
                request.slot_id,
                None,  # Don't provide building_name to avoid example data confusion
                request.map_id,
                request.level,
            )

        # If not found by map_id or no map_id provided, try database-first search
        if not current_slot_info:
            # Try database-only search first (no building name to avoid example data)
            db_result = storage_manager.find_slot_by_id(request.slot_id)
            logging.info(
                f"Database search for slot {request.slot_id}: {'Found' if db_result else 'Not found'}"
            )
            if db_result:
                logging.info(
                    f"DB result - building: {db_result['building_name']}, map_id: {db_result['map_id']}, status: {db_result['slot']['status']}"
                )
                # Validate context if provided
                context_matches = True
                if (
                    request.building_name
                    and db_result["building_name"].lower()
                    != request.building_name.lower()
                ):
                    context_matches = False
                    logging.info(
                        f"Building name mismatch: request={request.building_name}, db={db_result['building_name']}"
                    )
                if request.map_id and db_result["map_id"] != request.map_id:
                    context_matches = False
                    logging.info(
                        f"Map ID mismatch: request={request.map_id}, db={db_result['map_id']}"
                    )
                if request.level is not None and db_result["level"] != request.level:
                    context_matches = False
                    logging.info(
                        f"Level mismatch: request={request.level}, db={db_result['level']}"
                    )

                if context_matches:
                    current_slot_info = db_result
                    logging.info(
                        f"Using database data - slot status: {current_slot_info['slot']['status']}"
                    )
                else:
                    logging.info(
                        "Database result doesn't match context, will try context search"
                    )

        # If still not found, fall back to context search (which might find example data)
        if not current_slot_info:
            logging.info(
                "No database result, trying context search (may find example data)"
            )
            current_slot_info = find_slot_by_id_with_context(
                request.slot_id, request.building_name, request.map_id, request.level
            )
            if current_slot_info:
                logging.info(
                    f"Context search result - building: {current_slot_info['building_name']}, map_id: {current_slot_info['map_id']}, status: {current_slot_info['slot']['status']}"
                )
            else:
                logging.warning(f"No slot found in context search either")
        if not current_slot_info:
            logging.warning(f"Slot {request.slot_id} not found")
            raise HTTPException(status_code=404, detail="Parking slot not found")

        # Validate the slot is in the correct context
        context_matches = True
        context_errors = []

        if request.building_name:
            if (
                current_slot_info["building_name"].lower()
                != request.building_name.lower()
            ):
                context_matches = False
                context_errors.append(f"building '{request.building_name}'")

        if request.map_id:
            if current_slot_info["map_id"] != request.map_id:
                context_matches = False
                context_errors.append(f"map_id '{request.map_id}'")

        if request.level is not None:
            if current_slot_info["level"] != request.level:
                context_matches = False
                context_errors.append(f"level {request.level}")

        if not context_matches:
            error_msg = (
                f"Slot '{request.slot_id}' found but not in the specified {', '.join(context_errors)}. "
                f"Actual context: building='{current_slot_info['building_name']}', "
                f"map_id='{current_slot_info['map_id']}', level={current_slot_info['level']}"
            )
            logging.warning(error_msg)
            raise HTTPException(status_code=400, detail=error_msg)

        # Extract current_status from the found slot for context validation and response
        current_status = current_slot_info["slot"]["status"]

        logging.info(
            f"EXTRACTED current_status: '{current_status}' from map_id: {current_slot_info['map_id']}"
        )
        logging.info(
            f"Slot {request.slot_id} validated in context: building='{current_slot_info['building_name']}', "
            f"map_id='{current_slot_info['map_id']}', level={current_slot_info['level']}"
        )

        # Check if this is example data - if so, convert to database entry
        converted_from_example = False
        if current_slot_info["map_id"] == EXAMPLE_MAP_ID:
            logging.info(
                f"Converting example data to database entry for slot update: {request.slot_id}"
            )

            # Convert example map to real database entry (similar to parking module approach)
            from datetime import datetime

            new_map_data = {
                "building_name": current_slot_info["building_name"],
                "parking_map": copy.deepcopy(example_map),
                "analysis_engine": "example_data_converted_for_admin_update",
                "analysis_timestamp": datetime.utcnow().isoformat(),
                "original_filename": "example_map_converted_via_admin.jpg",
                "grid_size": {"rows": 6, "cols": 6},
                "gpt4o_analysis": {
                    "source": "example_data_converted_for_slot_update",
                    "converted_by": "admin",
                },
                "validation_result": {"is_valid": True, "converted_from_example": True},
                "file_size": 0,
            }

            # Save to database
            try:
                analysis_id = storage_manager.save_image_and_analysis(
                    temp_image_path="",  # No image for converted example data
                    original_filename="example_map_converted_via_admin.jpg",
                    building_name=current_slot_info["building_name"],
                    gpt4o_analysis=new_map_data["gpt4o_analysis"],
                    parking_map=new_map_data["parking_map"],
                    validation_result=new_map_data["validation_result"],
                    grid_size=new_map_data["grid_size"],
                    file_size=0,
                )

                # Update current_slot_info to point to the new database entry
                current_slot_info["map_id"] = analysis_id
                converted_from_example = True

                logging.info(
                    f"Successfully converted example data to database entry with ID: {analysis_id}"
                )

            except Exception as e:
                logging.error(f"Failed to convert example data to database: {e}")
                raise HTTPException(
                    status_code=500,
                    detail=f"Failed to convert example data to database for updating: {str(e)}",
                )

        # Prepare parameters based on status - ensure proper field clearing
        update_vehicle_id = request.vehicle_id
        update_reserved_by = request.reserved_by

        # Override parameters based on status to ensure proper field management
        if request.new_status == "available":
            # For available slots, always clear vehicle_id and reserved_by regardless of input
            update_vehicle_id = None
            update_reserved_by = None
        elif request.new_status == "allocated":
            # For allocated slots, keep both vehicle_id and reserved_by
            # reserved_by is required for allocated status (validated by pydantic)
            # vehicle_id can be provided to specify which vehicle the slot is allocated for
            pass
        elif request.new_status == "occupied":
            # For occupied slots, keep both vehicle_id and reserved_by as provided
            # reserved_by is required for occupied status (validated by pydantic)
            pass

        # Get the current status from database right before update
        actual_current_slot = storage_manager.find_slot_by_id(request.slot_id)
        if actual_current_slot:
            actual_current_status = actual_current_slot["slot"]["status"]
            logging.info(
                f"ACTUAL database current_status before update: '{actual_current_status}'"
            )
            # Use the actual database status as old_status for the response
            current_status = actual_current_status
        else:
            logging.info(
                f"No database entry found, using context search status: '{current_status}'"
            )

        # Update the slot in database
        success = storage_manager.update_slot_status(
            slot_id=request.slot_id,
            new_status=request.new_status,
            vehicle_id=update_vehicle_id,
            reserved_by=update_reserved_by,
        )

        if not success:
            raise HTTPException(status_code=500, detail="Failed to update parking slot")

        # Record successful operation
        metrics.increment_counter(
            "AdminOperations", {"operation": "update_slot_status"}
        )

        logging.info(
            f"Slot {request.slot_id} updated successfully from {current_status} to {request.new_status} by admin: {request.username}"
        )

        response = {
            "success": True,
            "message": "Parking slot status updated successfully",
            "slot_id": request.slot_id,
            "old_status": current_status,
            "new_status": request.new_status,
            "updated_by": request.username,
            "building_name": current_slot_info["building_name"],
            "map_id": current_slot_info["map_id"],
            "level": current_slot_info["level"],
            "vehicle_id": update_vehicle_id,  # Use actual updated values
            "reserved_by": update_reserved_by,  # Use actual updated values
            "context_validated": {
                "building_name": request.building_name,
                "map_id": request.map_id,
                "level": request.level,
            },
        }

        # Add conversion info if example data was converted
        if converted_from_example:
            response["converted_from_example"] = True
            response["message"] = (
                "Parking slot status updated successfully (example data converted to database)"
            )
            response["conversion_info"] = {
                "original_map_id": EXAMPLE_MAP_ID,
                "new_map_id": current_slot_info["map_id"],
                "note": "Example data was automatically converted to a database entry to enable updates",
            }

        return response

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to update slot {request.slot_id}: {e}")
        metrics.increment_counter(
            "AdminOperations", {"operation": "update_slot_status_failed"}
        )
        raise HTTPException(
            status_code=500, detail=f"Failed to update parking slot: {str(e)}"
        )
