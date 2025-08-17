from fastapi import APIRouter, Query, HTTPException, UploadFile, File
from typing import Optional, List, Dict, Any
from app.examples.example_map import example_map
from app.parking.models import (
    ParkingMapLevel,
    ParkingSlot,
    Entrance,
    Exit,
    RoadNode,
    Corridor,
    Wall,
    Ramp,
    ParkingFareRequest,
    ParkingFareResponse,
)
from app.parking.utils import (
    calculate_parking_fare,
    get_map_data,
    EXAMPLE_MAP_ID,
    EXAMPLE_BUILDINGS,
)
from app.pathfinding import PathPlanner
from app.vision import GPT4oVisionAPI
from app.config import settings
from app.parking.storage import storage_manager
import os
import tempfile
import shutil
import logging
from datetime import datetime
from app.cloudwatch_metrics import metrics

router = APIRouter(prefix="/parking", tags=["parking"])

# --- Move /upload-map endpoint to the very top ---


@router.post(
    "/upload-map",
    responses={
        200: {
            "description": "Successfully parsed parking map using GPT-4o Vision",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Parking lot map analyzed by GPT-4o Vision",
                        "parking_map": [
                            {
                                "building": "TOMLINSON",
                                "level": 1,
                                "size": {"rows": 10, "cols": 10},
                                "slots": [
                                    {
                                        "slot_id": "A1",
                                        "status": "available",
                                        "x": 2,
                                        "y": 2,
                                        "level": 1,
                                    }
                                ],
                                "gpt4o_analysis": {
                                    "total_parking_slots": "50+",
                                    "layout_type": "grid",
                                },
                            }
                        ],
                        "validation": {
                            "is_valid": True,
                            "ai_analysis": {"description": "GPT-4o analysis details"},
                        },
                    }
                }
            },
        },
        400: {
            "description": "Invalid file or GPT-4o analysis failed",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidFileType": {
                            "summary": "Invalid file type",
                            "value": {
                                "detail": "Only image file formats are supported (jpg, jpeg, png, bmp)"
                            },
                        },
                        "NoAPIKey": {
                            "summary": "Missing OpenAI API key",
                            "value": {
                                "detail": "OpenAI API key required for GPT-4o Vision analysis"
                            },
                        },
                        "AnalysisFailed": {
                            "summary": "GPT-4o analysis failed",
                            "value": {
                                "detail": "GPT-4o Vision analysis failed. Please check image quality or try again."
                            },
                        },
                    }
                }
            },
        },
    },
)
def upload_parking_map(
    file: UploadFile = File(...),
    building_name: Optional[str] = Query(
        "Unknown Building", description="Building name"
    ),
    level: int = Query(1, description="Parking lot level"),
    grid_rows: Optional[int] = Query(10, description="Grid rows", ge=4, le=20),
    grid_cols: Optional[int] = Query(10, description="Grid columns", ge=4, le=20),
):
    """
    🤖 Upload parking lot image and analyze using GPT-4o Vision AI

    This endpoint uses OpenAI's GPT-4o Vision model for intelligent parking lot analysis.
    GPT-4o can understand the overall layout and identify parking slots more accurately than traditional CV methods.

    - **file**: Parking lot image file (jpg, jpeg, png, bmp)
    - **building_name**: Building name (optional, GPT-4o may detect it automatically)
    - **level**: Parking lot level (default 1)
    - **grid_rows**: Grid rows for coordinate mapping (default 10)
    - **grid_cols**: Grid columns for coordinate mapping (default 10)

    Returns intelligent analysis results from GPT-4o Vision
    """

    # Check if OpenAI API key is configured
    if not settings.is_openai_configured():
        raise HTTPException(
            status_code=500,
            detail="OpenAI API key not configured. Please contact administrator.",
        )

    # Validate file type
    allowed_extensions = {".jpg", ".jpeg", ".png", ".bmp"}
    file_extension = os.path.splitext(file.filename)[1].lower()

    if file_extension not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail="Only image file formats are supported (jpg, jpeg, png, bmp)",
        )

    # Validate file size (10MB limit)
    max_file_size = 10 * 1024 * 1024  # 10MB
    if file.size > max_file_size:
        raise HTTPException(status_code=400, detail="File size cannot exceed 10MB")

    # Duplicate name+level check
    existing = storage_manager.get_analysis_by_building_and_level(building_name, level)
    if existing:
        raise HTTPException(
            status_code=400,
            detail=f"A map for building '{building_name}' at level {level} already exists. Please use a different name/level or delete the old map first.",
        )

    temp_file = None
    try:
        # Save uploaded file to temporary directory
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=file_extension)
        shutil.copyfileobj(file.file, temp_file)
        temp_file.close()

        # Initialize GPT-4o Vision API
        grid_size = (grid_rows, grid_cols)
        gpt4o_api = GPT4oVisionAPI(
            grid_size=grid_size, openai_api_key=settings.get_openai_api_key()
        )

        # Process image with GPT-4o
        result = gpt4o_api.process_parking_image(temp_file.name, building_name)

        parking_map = result["parking_map"]
        validation_result = result["validation"]

        # --- Inject level into each level_data in parking_map ---
        for level_data in parking_map:
            level_data["level"] = level

        # Save image and analysis to storage
        try:
            analysis_id = storage_manager.save_image_and_analysis(
                temp_image_path=temp_file.name,
                original_filename=file.filename,
                building_name=building_name,
                gpt4o_analysis=validation_result.get("ai_analysis", {}),
                parking_map=parking_map,
                validation_result=validation_result,
                grid_size={"rows": grid_rows, "cols": grid_cols},
                file_size=file.size,
            )
            print(f"💾 Analysis saved with ID: {analysis_id}")
            storage_success = True
        except Exception as e:
            print(f"⚠️ Failed to save to storage: {e}")
            analysis_id = None
            storage_success = False

        return {
            "success": True,
            "message": "🤖 Parking lot map analyzed successfully by GPT-4o Vision",
            "parking_map": parking_map,
            "validation": validation_result,
            "storage": {"saved": storage_success, "analysis_id": analysis_id},
            "metadata": {
                "original_filename": file.filename,
                "file_size": file.size,
                "grid_size": {"rows": grid_rows, "cols": grid_cols},
                "building_name": building_name,
                "level": level,
                "ai_engine": "GPT-4o Vision",
            },
        }

    except ValueError as e:
        # Handle GPT-4o analysis failure
        print(f"GPT-4o analysis failed: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"GPT-4o processing error: {e}")
        raise HTTPException(
            status_code=500, detail=f"GPT-4o Vision processing failed: {str(e)}"
        )

    finally:
        # Clean up temporary file
        if temp_file and os.path.exists(temp_file.name):
            os.unlink(temp_file.name)


# --- Maps-related endpoints follow ---


@router.get(
    "/maps",
    responses={
        200: {
            "description": "List of uploaded parking maps",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "maps": [
                            {
                                "_id": "uuid-here",
                                "building_name": "WestfieldB27",
                                "original_filename": "parking_lot.jpg",
                                "upload_timestamp": "2024-01-01T12:00:00",
                                "grid_size": {"rows": 10, "cols": 10},
                                "total_slots": 45,
                                "analysis_engine": "GPT-4o Vision",
                            }
                        ],
                        "total": 5,
                    }
                }
            },
        }
    },
)
def get_all_maps():
    """
    🗺️ Get overview of all parking maps

    Returns basic information of all AI-converted parking maps in the system,
    plus example map data for demo purposes.
    """
    try:
        maps = storage_manager.get_recent_analyses(limit=50)  # Get latest 50 maps

        # Format map information, return only necessary fields
        formatted_maps = []
        for map_data in maps:
            formatted_map = {
                "_id": map_data.get("_id"),
                "building_name": map_data.get("building_name", "Unknown"),
                "original_filename": map_data.get("original_filename", "unknown.jpg"),
                "upload_timestamp": map_data.get("analysis_timestamp"),
                "grid_size": map_data.get("grid_size", {"rows": 10, "cols": 10}),
                "total_slots": (
                    len(map_data.get("parking_map", [{}])[0].get("slots", []))
                    if map_data.get("parking_map")
                    else 0
                ),
                "analysis_engine": map_data.get("analysis_engine", "GPT-4o Vision"),
            }
            formatted_maps.append(formatted_map)

        # Add example map to the list
        example_total_slots = sum(len(level.get("slots", [])) for level in example_map)
        example_map_info = {
            "_id": EXAMPLE_MAP_ID,
            "building_name": "Westfield Sydney (Example)",
            "original_filename": "example_map.jpg",
            "upload_timestamp": "2024-01-01T00:00:00Z",
            "grid_size": {"rows": 6, "cols": 6},
            "total_slots": example_total_slots,
            "analysis_engine": "example_data",
            "is_example": True,
        }
        formatted_maps.append(example_map_info)

        return {"success": True, "maps": formatted_maps, "total": len(formatted_maps)}
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to retrieve maps: {str(e)}"
        )


@router.get(
    "/maps/building/{building_name}",
    responses={
        200: {
            "description": "Map details by building name",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "building_name": "Westfield Sydney (Example)",
                        "map": {
                            "_id": "map_123",
                            "building_name": "Westfield Sydney (Example)",
                            "parking_map": [{"level": 1, "slots": []}],
                            "analysis_engine": "o3-mini",
                        },
                    }
                }
            },
        },
        404: {"description": "No map found for this building"},
    },
)
def get_map_by_building_name(building_name: str):
    """
    🏢 Get map details by building name

    Returns complete map information for the specified building.
    If multiple versions exist, returns the most recent one.
    Falls back to example data if no map is found in the database.
    """
    try:
        map_data = storage_manager.get_analysis_by_building_name(building_name)
        if map_data:
            return {
                "success": True,
                "building_name": building_name,
                "map": {
                    "_id": map_data.get("_id"),
                    "building_name": map_data.get("building_name"),
                    "original_filename": map_data.get("original_filename"),
                    "upload_timestamp": map_data.get("analysis_timestamp"),
                    "parking_map": map_data.get("parking_map", []),
                    "o3_analysis": map_data.get("gpt4o_analysis", {}),
                    "grid_size": map_data.get("grid_size", {"rows": 10, "cols": 10}),
                    "analysis_engine": map_data.get("analysis_engine", "o3-mini"),
                },
            }
        else:
            # Check if this building should use example data
            if building_name.lower() in EXAMPLE_BUILDINGS:
                logging.info(f"Using example data for building '{building_name}'")
                return {
                    "success": True,
                    "building_name": building_name,
                    "map": {
                        "_id": EXAMPLE_MAP_ID,
                        "building_name": building_name,
                        "original_filename": "example_map.jpg",
                        "upload_timestamp": "2024-01-01T00:00:00Z",
                        "parking_map": example_map,
                        "o3_analysis": {
                            "source": "example_data",
                            "total_slots": sum(
                                len(level.get("slots", [])) for level in example_map
                            ),
                        },
                        "grid_size": {"rows": 6, "cols": 6},
                        "analysis_engine": "example_data",
                        "is_example": True,
                    },
                }
            else:
                # Fallback to example data for demo (original behavior)
                logging.info(
                    f"No map found for building '{building_name}', using example data"
                )
                return {
                    "success": True,
                    "building_name": building_name,
                    "map": {
                        "_id": EXAMPLE_MAP_ID,
                        "building_name": building_name,
                        "original_filename": "example_map.jpg",
                        "upload_timestamp": "2024-01-01T00:00:00Z",
                        "parking_map": example_map,
                        "o3_analysis": {
                            "source": "example_data",
                            "total_slots": sum(
                                len(level.get("slots", [])) for level in example_map
                            ),
                        },
                        "grid_size": {"rows": 6, "cols": 6},
                        "analysis_engine": "example_data",
                        "is_example": True,
                    },
                }
    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to get map for building {building_name}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve map: {str(e)}")


@router.get(
    "/maps/{map_id}",
    responses={
        200: {
            "description": "Detailed map information for editing",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "map": {
                            "_id": "uuid-here",
                            "building_name": "WestfieldB27",
                            "parking_map": [
                                {
                                    "building": "WestfieldB27",
                                    "level": 1,
                                    "size": {"rows": 10, "cols": 10},
                                    "slots": [
                                        {
                                            "slot_id": "A1",
                                            "status": "available",
                                            "x": 2,
                                            "y": 3,
                                            "level": 1,
                                        }
                                    ],
                                    "entrances": [],
                                    "exits": [],
                                    "corridors": [],
                                    "walls": [],
                                }
                            ],
                            "gpt4o_analysis": {
                                "total_parking_slots": "45",
                                "layout_type": "grid",
                                "complexity": "medium",
                            },
                            "editable": True,
                        },
                    }
                }
            },
        },
        404: {"description": "Map not found"},
    },
)
def get_map_for_editing(map_id: str):
    """
    ✏️ Get detailed map information for editing

    Returns complete information of specified map, including GPT-4o analysis results and editable parking data

    - **map_id**: Unique identifier of the map
    """
    try:
        # Handle example map
        if map_id == EXAMPLE_MAP_ID:
            return {
                "success": True,
                "map": {
                    "_id": EXAMPLE_MAP_ID,
                    "building_name": "Westfield Sydney (Example)",
                    "original_filename": "example_map.jpg",
                    "upload_timestamp": "2024-01-01T00:00:00Z",
                    "parking_map": example_map,
                    "gpt4o_analysis": {
                        "source": "example_data",
                        "total_slots": sum(
                            len(level.get("slots", [])) for level in example_map
                        ),
                    },
                    "validation_result": {"is_valid": True},
                    "grid_size": {"rows": 6, "cols": 6},
                    "file_size": 0,
                    "analysis_engine": "example_data",
                    "editable": True,
                    "is_example": True,
                },
            }

        # Handle regular database maps
        map_data = storage_manager.get_analysis_by_id(map_id)
        if not map_data:
            raise HTTPException(status_code=404, detail="Map not found")

        return {
            "success": True,
            "map": {
                "_id": map_data.get("_id"),
                "building_name": map_data.get("building_name"),
                "original_filename": map_data.get("original_filename"),
                "upload_timestamp": map_data.get("analysis_timestamp"),
                "parking_map": map_data.get("parking_map", []),
                "gpt4o_analysis": map_data.get("gpt4o_analysis", {}),
                "validation_result": map_data.get("validation_result", {}),
                "grid_size": map_data.get("grid_size", {"rows": 10, "cols": 10}),
                "file_size": map_data.get("file_size"),
                "analysis_engine": map_data.get("analysis_engine", "GPT-4o Vision"),
                "editable": True,
            },
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve map: {str(e)}")


@router.put(
    "/maps/update",
    responses={
        200: {
            "description": "Map updated successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Map updated successfully",
                        "updated_map": {
                            "_id": "uuid-here",
                            "building_name": "WestfieldB27",
                            "last_modified": "2024-01-01T13:00:00",
                        },
                    }
                }
            },
        },
        404: {"description": "Map not found"},
        400: {"description": "Invalid map data or missing parameters"},
    },
)
def update_map_by_id_or_name(
    updated_map: dict,
    map_id: Optional[str] = Query(None, description="Map ID"),
    building_name: Optional[str] = Query(None, description="Building name"),
):
    """
    Update parking map information by map_id or building_name.
    If both are provided, map_id takes precedence.

    Supports both AI-generated maps and example maps.
    If updating an example map, it will be saved to database as a real map.
    """
    try:
        # 1. find target map
        existing_map = None
        is_example_map = False

        if map_id:
            if map_id == EXAMPLE_MAP_ID:
                # Handle example map update
                is_example_map = True
                existing_map = {
                    "_id": EXAMPLE_MAP_ID,
                    "building_name": building_name or "Westfield Sydney (Example)",
                    "parking_map": example_map,
                    "analysis_engine": "example_data",
                }
            else:
                existing_map = storage_manager.get_analysis_by_id(map_id)
        elif building_name:
            existing_map = storage_manager.get_analysis_by_building_name(building_name)
            if not existing_map:
                # Check if this building should use example data
                if building_name.lower() in EXAMPLE_BUILDINGS:
                    is_example_map = True
                    existing_map = {
                        "_id": EXAMPLE_MAP_ID,
                        "building_name": building_name,
                        "parking_map": example_map,
                        "analysis_engine": "example_data",
                    }
        else:
            raise HTTPException(
                status_code=400,
                detail="You must provide either map_id or building_name.",
            )

        if not existing_map:
            raise HTTPException(status_code=404, detail="Map not found")

        # 2. handle example map update
        if is_example_map:
            # Convert example map to real database entry
            new_map_data = {
                "building_name": existing_map["building_name"],
                "parking_map": updated_map.get(
                    "parking_map", existing_map["parking_map"]
                ),
                "analysis_engine": "example_data_updated",
                "analysis_timestamp": datetime.utcnow().isoformat(),
                "original_filename": "example_map_updated.jpg",
                "grid_size": updated_map.get("grid_size", {"rows": 6, "cols": 6}),
                "gpt4o_analysis": updated_map.get(
                    "gpt4o_analysis", {"source": "example_data_updated"}
                ),
                "validation_result": updated_map.get(
                    "validation_result", {"is_valid": True}
                ),
                "file_size": 0,
            }

            # Save to database
            analysis_id = storage_manager.save_image_and_analysis(
                temp_image_path="",  # No image for example data
                original_filename="example_map_updated.jpg",
                building_name=existing_map["building_name"],
                gpt4o_analysis=new_map_data["gpt4o_analysis"],
                parking_map=new_map_data["parking_map"],
                validation_result=new_map_data["validation_result"],
                grid_size=new_map_data["grid_size"],
                file_size=0,
            )

            return {
                "success": True,
                "message": "Example map converted and updated successfully",
                "updated_map": {
                    "_id": analysis_id,
                    "building_name": existing_map["building_name"],
                    "last_modified": new_map_data["analysis_timestamp"],
                    "converted_from_example": True,
                },
            }

        # 3. existing database map
        target_id = existing_map.get("_id")
        success = storage_manager.update_analysis(target_id, updated_map)
        if not success:
            raise HTTPException(status_code=500, detail="Failed to update map")

        return {
            "success": True,
            "message": "Map updated successfully",
            "updated_map": {
                "_id": target_id,
                "building_name": updated_map.get(
                    "building_name", existing_map.get("building_name")
                ),
                "last_modified": datetime.utcnow().isoformat(),
            },
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update map: {str(e)}")


@router.get(
    "/slots",
    responses={
        200: {
            "description": "List of parking slots",
            "content": {
                "application/json": {
                    "example": [
                        {"slot_id": "1A", "status": "free", "x": 2, "y": 3},
                        {"slot_id": "1B", "status": "occupied", "x": 4, "y": 3},
                    ]
                }
            },
        },
        500: {
            "description": "Failed to load real-time parking slot data.",
            "content": {
                "application/json": {
                    "example": {"detail": "Failed to load real-time parking slot data."}
                }
            },
        },
    },
)
def get_parking_slots(
    level: Optional[int] = None,
    building_name: Optional[str] = None,
    map_id: Optional[str] = None,
):
    """
    🅿️ Get parking slots from specific map

    Query slots by either building name or map ID. If neither is provided,
    returns example data for demo purposes.

    - **level**: Optional level filter
    - **building_name**: Building name to search for
    - **map_id**: Map ID to search for
    """
    try:
        # use general function to get map data
        map_data = get_map_data(map_id, building_name)

        if map_data:
            # get parking slots from specified map
            all_slots = []
            for level_data in map_data.get("parking_map", []):
                if level is None or level_data.get("level") == level:
                    all_slots.extend(level_data.get("slots", []))

            return {
                "success": True,
                "building_name": map_data.get("building_name"),
                "map_id": map_data.get("_id"),
                "level_filter": level,
                "slots": all_slots,
                "total": len(all_slots),
                "source": map_data.get("source", "unknown"),
            }
        else:
            # if no map is specified, use example data as default
            logging.info(
                f"Using example data for slots (level: {level if level is not None else 'all'})"
            )
            if level is not None:
                for l in example_map:
                    if l["level"] == level:
                        return {
                            "slots": l["slots"],
                            "total": len(l["slots"]),
                            "source": "example",
                        }
                return {"slots": [], "total": 0, "source": "example"}

            all_slots = []
            for l in example_map:
                all_slots.extend(l["slots"])
            return {"slots": all_slots, "total": len(all_slots), "source": "example"}

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to load parking slot data: {e}")
        raise HTTPException(status_code=500, detail="Failed to load parking slot data.")


@router.get(
    "/slots/summary",
    responses={
        200: {
            "description": "Summary of parking slots",
            "content": {
                "application/json": {
                    "example": {"occupied": 2, "free": 3, "allocated": 1, "total": 6}
                }
            },
        },
        500: {
            "description": "Failed to load summary data.",
            "content": {
                "application/json": {
                    "example": {"detail": "Failed to load summary data."}
                }
            },
        },
    },
)
def get_parking_slot_summary(
    level: Optional[int] = None,
    building_name: Optional[str] = None,
    map_id: Optional[str] = None,
):
    """
    📊 Get parking slots summary from specific map

    Query summary by either building name or map ID. If neither is provided,
    returns example data for demo purposes.

    - **level**: Optional level filter
    - **building_name**: Building name to search for
    - **map_id**: Map ID to search for
    """
    try:
        # use general function to get map data
        map_data = get_map_data(map_id, building_name)

        if map_data:
            # get parking slots summary from specified map
            summary = {"occupied": 0, "available": 0, "allocated": 0, "total": 0}
            for level_data in map_data.get("parking_map", []):
                if level is None or level_data.get("level") == level:
                    for slot in level_data.get("slots", []):
                        summary["total"] += 1
                        status = slot.get("status", "available").lower()
                        if status == "occupied":
                            summary["occupied"] += 1
                        elif status == "allocated":
                            summary["allocated"] += 1
                        else:
                            summary["available"] += 1

            return {
                "success": True,
                "building_name": map_data.get("building_name"),
                "map_id": map_data.get("_id"),
                "level_filter": level,
                "summary": summary,
                "source": map_data.get("source", "unknown"),
            }
        else:
            # Fallback to example data for demo
            slots = []
            if level is not None:
                for l in example_map:
                    if l["level"] == level:
                        slots = l["slots"]
                        break
            else:
                for l in example_map:
                    slots.extend(l["slots"])
            occupied = sum(1 for s in slots if s["status"] == "occupied")
            allocated = sum(1 for s in slots if s["status"] == "allocated")
            available = sum(1 for s in slots if s["status"] in ["free", "available"])
            summary = {
                "occupied": occupied,
                "allocated": allocated,
                "available": available,
                "total": len(slots),
            }
            return {"summary": summary, "source": "example"}

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to load summary data: {e}")
        raise HTTPException(status_code=500, detail="Failed to load summary data.")


@router.get(
    "/entrances",
    responses={
        200: {
            "description": "List of entrances",
            "content": {
                "application/json": {"example": [{"entrance_id": "E1", "x": 0, "y": 0}]}
            },
        }
    },
)
def get_entrances(
    level: Optional[int] = None,
    building_name: Optional[str] = None,
    map_id: Optional[str] = None,
):
    """
    🚪 Get entrances from specific map

    Query entrances by either building name or map ID. If neither is provided,
    returns example data for demo purposes.

    - **level**: Optional level filter
    - **building_name**: Building name to search for
    - **map_id**: Map ID to search for
    """
    try:
        # use general function to get map data
        map_data = get_map_data(map_id, building_name)

        if map_data:
            # get entrances from specified map
            all_entrances = []
            for level_data in map_data.get("parking_map", []):
                if level is None or level_data.get("level") == level:
                    all_entrances.extend(level_data.get("entrances", []))

            return {
                "success": True,
                "building_name": map_data.get("building_name"),
                "map_id": map_data.get("_id"),
                "level_filter": level,
                "entrances": all_entrances,
                "total": len(all_entrances),
                "source": map_data.get("source", "unknown"),
            }
        else:
            # Fallback to example data for demo
            entrances = []
            for l in example_map:
                if level is None or l["level"] == level:
                    entrances.extend(l.get("entrances", []))
            return {
                "entrances": entrances,
                "total": len(entrances),
                "source": "example",
            }

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to load entrances: {e}")
        raise HTTPException(status_code=500, detail="Failed to load entrances.")


@router.get(
    "/exits",
    responses={
        200: {
            "description": "List of exits",
            "content": {
                "application/json": {"example": [{"exit_id": "X1", "x": 10, "y": 0}]}
            },
        }
    },
)
def get_exits(
    level: Optional[int] = None,
    building_name: Optional[str] = None,
    map_id: Optional[str] = None,
):
    """
    🚪 Get exits from specific map

    Query exits by either building name or map ID. If neither is provided,
    returns example data for demo purposes.

    - **level**: Optional level filter
    - **building_name**: Building name to search for
    - **map_id**: Map ID to search for
    """
    try:
        # use general function to get map data
        map_data = get_map_data(map_id, building_name)

        if map_data:
            # get exits from specified map
            all_exits = []
            for level_data in map_data.get("parking_map", []):
                if level is None or level_data.get("level") == level:
                    all_exits.extend(level_data.get("exits", []))

            return {
                "success": True,
                "building_name": map_data.get("building_name"),
                "map_id": map_data.get("_id"),
                "level_filter": level,
                "exits": all_exits,
                "total": len(all_exits),
                "source": map_data.get("source", "unknown"),
            }
        else:
            # Fallback to example data for demo
            exits = []
            for l in example_map:
                if level is None or l["level"] == level:
                    exits.extend(l.get("exits", []))
            return {"exits": exits, "total": len(exits), "source": "example"}

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Failed to load exits: {e}")
        raise HTTPException(status_code=500, detail="Failed to load exits.")


@router.post(
    "/predict-fare",
    response_model=ParkingFareResponse,
    responses={
        200: {
            "description": "Parking fare calculated successfully",
            "content": {
                "application/json": {
                    "example": {
                        "destination": "Westfield Sydney (Example)",
                        "parking_date": "2025-07-16",
                        "parking_start_time": "14:30",
                        "parking_end_time": "16:30",
                        "duration_hours": 2,
                        "breakdown": {
                            "base_rate_per_hour": 6.00,
                            "total_duration_base_cost": 12.00,
                            "peak_hour_surcharge": 0.00,
                            "weekend_surcharge": 0.00,
                            "public_holiday_surcharge": 0.00,
                            "total": 12.00,
                        },
                        "currency": "AUD",
                    }
                }
            },
        },
        400: {
            "description": "Invalid input data",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidDate": {
                            "summary": "Invalid date format",
                            "value": {"detail": "Date must be in YYYY-MM-DD format"},
                        },
                        "InvalidTime": {
                            "summary": "Invalid time format",
                            "value": {"detail": "Time must be in HH:MM format"},
                        },
                        "InvalidDuration": {
                            "summary": "Invalid duration",
                            "value": {
                                "detail": "Duration must be between 1 and 24 hours"
                            },
                        },
                    }
                }
            },
        },
        500: {"description": "Internal server error during fare calculation"},
    },
)
def predict_parking_fare(request: ParkingFareRequest):
    """
    Predicts parking fare based on destination, date, time, and duration

    **This parking fare prediction feature calculates parking fees by considering:**
    - **Base rate**: Varies by destination
    - **Peak hour surcharge**: Applied during weekday rush hours (7-9 AM, 5-7 PM)
    - **Weekend surcharge**: Applied on Saturdays and Sundays
    - **Public holiday surcharge**: Applied on recognized public holidays

    **Input Requirements:**
     - **destination**: Parking location name (required)
     - **date**: Date in YYYY-MM-DD format (optional)
     - **time**: Time in HH:MM format (optional)
     - **duration_hours**: Parking duration (1-24 hours) (optional, defaults to 2 hours)

    **Supported Destinations:**
    - Westfield Sydney (Example)
    - Westfield Bondi Junction
    - Westfield Parramatta
    - Westfield Chatswood
    - (Other destinations use default rates)

    Returns detailed fare breakdown including all applicable surcharges.
    """
    try:
        # Log the fare prediction request
        logging.info(
            f"Fare prediction request for {request.destination} on {request.date} {request.time}"
        )

        # Record metrics
        metrics.increment_counter(
            "FarePredictionRequests", {"destination": request.destination}
        )

        # Calculate fare using the utility function
        fare_response = calculate_parking_fare(request)

        # Log successful calculation
        total_fare = fare_response.breakdown["total"]
        logging.info(
            f"Fare calculated: ${total_fare:.2f} AUD for {request.destination}"
        )

        # Record fare amount metric
        metrics.put_metric(
            "FareAmount", total_fare, "None", {"destination": request.destination}
        )

        return fare_response

    except ValueError as e:
        logging.error(f"Validation error in fare prediction: {e}")
        metrics.increment_counter(
            "FarePredictionErrors",
            {"error_type": "validation", "destination": request.destination},
        )
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logging.error(f"Unexpected error in fare prediction: {e}")
        metrics.increment_counter(
            "FarePredictionErrors",
            {"error_type": "system", "destination": request.destination},
        )
        raise HTTPException(
            status_code=500, detail=f"Failed to calculate parking fare: {str(e)}"
        )


@router.get(
    "/destination-parking-rate",
    responses={
        200: {
            "description": "Parking rates for the specified destination",
            "content": {
                "application/json": {
                    "example": {
                        "destination": "Westfield Sydney (Example)",
                        "base_rate_per_hour": 6.0,
                        "peak_hour_surcharge_rate": 0.6,
                        "weekend_surcharge_rate": 0.4,
                        "public_holiday_surcharge_rate": 1.0,
                        "peak_hours": {
                            "weekday": {
                                "morning": {"start": "07:00", "end": "09:00"},
                                "evening": {"start": "17:00", "end": "19:00"},
                            }
                        },
                        "uses_default_rates": False,
                        "currency": "AUD",
                    }
                }
            },
        },
        400: {"description": "Missing destination"},
        500: {"description": "Failed to load parking rates"},
    },
)
def get_destination_parking_rate(
    destination: str = Query(
        ..., description="Destination name to get parking rates for"
    )
):
    """
    Get parking rates for a specific destination

    Returns the parking rates and surcharge multipliers for the specified destination.
    If the destination is not one of the supported destinations, returns default rates.

    - **destination**: Name of the parking destination
    """
    try:
        from app.parking.utils import load_parking_rates, get_destination_rates

        rates_config = load_parking_rates()
        destination_rates = get_destination_rates(destination, rates_config)

        # Check if this destination uses default rates
        uses_default = destination not in rates_config.get("destinations", {})

        return {
            "destination": destination,
            "base_rate_per_hour": destination_rates.get("base_rate_per_hour", 0.0),
            "peak_hour_surcharge_rate": destination_rates.get(
                "peak_hour_surcharge_rate", 0.0
            ),
            "weekend_surcharge_rate": destination_rates.get(
                "weekend_surcharge_rate", 0.0
            ),
            "public_holiday_surcharge_rate": destination_rates.get(
                "public_holiday_surcharge_rate", 0.0
            ),
            "peak_hours": rates_config.get("peak_hours", {}),
            "uses_default_rates": uses_default,
            "currency": rates_config.get("currency", "AUD"),
        }

    except Exception as e:
        logging.error(
            f"Failed to load parking rates for destination {destination}: {e}"
        )
        raise HTTPException(status_code=500, detail="Failed to load parking rates")
