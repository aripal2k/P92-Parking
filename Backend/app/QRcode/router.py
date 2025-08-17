from fastapi import APIRouter, HTTPException, Query, Body
from pydantic import BaseModel
from datetime import datetime, timedelta, timezone
import qrcode
import io
import base64
from typing import Optional, Dict, Any, List
from app.database import db
from app.parking.storage import storage_manager
from app.examples.example_map import example_map
from fastapi.responses import StreamingResponse
import json
from app.cloudwatch_metrics import metrics

router = APIRouter(prefix="/qr", tags=["qr"])


class QRValidateRequest(BaseModel):
    qr_content: Dict[str, Any]


class QRBase64ToImageRequest(BaseModel):
    qr_image_base64: str


# add entrance qr code generation API
@router.get(
    "/generate-entrance-qr",
    responses={
        200: {
            "description": "Entrance QR code generated successfully",
            "content": {
                "application/json": {
                    "example": {
                        "qr_image_base64": "...base64...",
                        "entrance_id": "E1",
                        "building": "ShoppingMall",
                        "level": 1,
                        "coordinates": {"x": 10, "y": 20},
                    }
                }
            },
        },
        400: {
            "description": "Invalid entrance ID",
            "content": {
                "application/json": {
                    "example": {"detail": "Entrance 'E999' not found."}
                }
            },
        },
    },
)
def generate_entrance_qr(
    entrance_id: str = Query(..., description="ID of the entrance"),
    building_name: str = Query(..., description="Name of the building/parking lot"),
    format_type: str = Query(
        "json", description="Format type of QR code: 'json', 'simple', or 'param'"
    ),
):
    """
    Generate a static QR code for a parking entrance.

    This endpoint creates a QR code that will be displayed at a specific parking entrance.
    The QR code contains the entrance location information needed by the mobile app.

    When scanned by the app, this QR code will allow the system to identify the user's
    starting position for navigation and parking spot allocation.

    Available formats:
    - json: {"entrance_id": "E1", "building": "Mall", "level": 1, "coordinates": {"x": 10, "y": 20}}
    - simple: ENTRANCE_MALL_E1_1_10_20
    - param: entrance=E1&building=Mall&level=1&x=10&y=20
    """
    # Validate if entrance exists
    entrance_data = None
    level = None

    # First, try to find entrance in MongoDB
    try:
        # Look for the map in MongoDB
        map_doc = db["maps"].find_one({"building_name": building_name})
        if map_doc and "parking_map" in map_doc:
            for map_level in map_doc["parking_map"]:
                if map_level.get("building") == building_name:
                    level = map_level.get("level", 1)
                    for entrance in map_level.get("entrances", []):
                        if entrance.get("entrance_id") == entrance_id:
                            entrance_data = entrance
                            break
                    if entrance_data:
                        break
    except Exception as e:
        print(f"Error searching MongoDB: {e}")

    # If not found in MongoDB, try example_map as fallback
    if not entrance_data:
        for map_level in example_map:
            if map_level.get("building") == building_name:
                level = map_level.get("level", 1)
                for entrance in map_level.get("entrances", []):
                    if entrance.get("entrance_id") == entrance_id:
                        entrance_data = entrance
                        break
                if entrance_data:
                    break

    if not entrance_data:
        raise HTTPException(
            status_code=400,
            detail=f"Entrance '{entrance_id}' not found in building '{building_name}'.",
        )

    # Extract coordinates
    x = entrance_data.get("x", 0)
    y = entrance_data.get("y", 0)

    # Create QR code content based on format type
    qr_content = None
    if format_type == "json":
        qr_content = {
            "entrance_id": entrance_id,
            "building": building_name,
            "level": level,
            "coordinates": {"x": x, "y": y},
        }
        qr_string = json.dumps(qr_content)
    elif format_type == "simple":
        qr_string = f"ENTRANCE_{building_name}_{entrance_id}_{level}_{x}_{y}"
        qr_content = qr_string
    elif format_type == "param":
        qr_string = (
            f"entrance={entrance_id}&building={building_name}&level={level}&x={x}&y={y}"
        )
        qr_content = qr_string
    else:
        raise HTTPException(
            status_code=400, detail=f"Unsupported format type: {format_type}"
        )

    # Generate QR code image
    qr = qrcode.make(qr_string)
    buf = io.BytesIO()
    qr.save(buf, format="PNG")
    img_b64 = base64.b64encode(buf.getvalue()).decode()

    # Save to database for reference
    db["entrance_qrcodes"].insert_one(
        {
            "entrance_id": entrance_id,
            "building": building_name,
            "level": level,
            "coordinates": {"x": x, "y": y},
            "format_type": format_type,
            "qr_content": qr_content,
            "qr_image_base64": img_b64,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
    )

    # Return both QR image and entrance data
    return {
        "qr_image_base64": img_b64,
        "entrance_id": entrance_id,
        "building": building_name,
        "level": level,
        "coordinates": {"x": x, "y": y},
        "format_type": format_type,
        "qr_content": qr_content,
    }


# @router.post("/generate",
#     responses={
#         200: {
#             "description": "QR code generated successfully",
#             "content": {
#                 "application/json": {
#                     "example": {
#                         "qr_image_base64": "...base64...",
#                         "expire_at": "2025-07-16T17:46:01.744596+00:00"
#                     }
#                 }
#             }
#         },
#         400: {
#             "description": "Invalid input or destination does not exist",
#             "content": {
#                 "application/json": {
#                     "examples": {
#                         "InvalidDestination": {
#                             "summary": "Destination does not exist",
#                             "value": {"detail": "Destination 'xxx' does not exist."}
#                         },
#                         "InvalidDateTime": {
#                             "summary": "Invalid date or time format",
#                             "value": {"detail": "Invalid date or time format. Use yyyy-mm-dd and HH:MM."}
#                         }
#                     }
#                 }
#             }
#         }
#     }
# )
# def generate_qr(
#     username: str = Query(..., description="Username of the user"),
#     destination: str = Query(..., description="Destination"),
#     store: Optional[str] = Query(None, description="Store (optional)"),
#     date: Optional[str] = Query(None, description="Date (optional, yyyy-mm-dd)"),
#     time: Optional[str] = Query(None, description="Time (optional, HH:MM)"),
#     entrance: Optional[str] = Query(None, description="Entrance (optional, choose a specific entrance)")
# ):
#     """
#     Generate a QR code for parking access or reservation.
#     If date and time are not provided, the QR code is valid for 10 minutes from now (UTC).
#     If date and time are provided, the QR code is valid for 15 minutes after the specified datetime (assumed UTC).
#     All times are in UTC and include timezone info.
#     If entrance is specified, only include that entrance in the QR code content.
#     """
#     # check if destination is a valid parking lot
#     valid_buildings = set(m["building"] for m in example_map)
#     if destination not in valid_buildings:
#         raise HTTPException(status_code=400, detail=f"Destination '{destination}' does not exist.")

#     # Collect all entrances for the destination
#     entrances = []
#     for m in example_map:
#         if m["building"] == destination and "entrances" in m:
#             entrances.extend(m["entrances"])

#     # entrance parameter validation and filtering (supports entrances as dictionary list)
#     if entrance:
#         entrance_ids = [e["entrance_id"] for e in entrances]
#         if entrance not in entrance_ids:
#             raise HTTPException(status_code=400, detail=f"Entrance '{entrance}' does not exist for destination '{destination}'.")
#         entrances = [e for e in entrances if e["entrance_id"] == entrance]

#     now = datetime.now(timezone.utc)
#     # Calculate expire_at
#     if date and time:
#         try:
#             dt = datetime.strptime(f"{date} {time}", "%Y-%m-%d %H:%M")
#             dt = dt.replace(tzinfo=timezone.utc)
#         except Exception:
#             raise HTTPException(status_code=400, detail="Invalid date or time format. Use yyyy-mm-dd and HH:MM.")
#         expire_at = dt + timedelta(minutes=15)
#     else:
#         expire_at = now + timedelta(minutes=10)
#     # Assemble QR code content
#     qr_content = {
#         "username": username,
#         "destination": destination,
#         "expire_at": expire_at.isoformat(),
#         "entrances": entrances
#     }
#     if store:
#         qr_content["store"] = store
#     if date:
#         qr_content["date"] = date
#     if time:
#         qr_content["time"] = time
#     # Generate QR code image (base64, for backward compatibility)
#     qr = qrcode.make(qr_content)
#     buf = io.BytesIO()
#     qr.save(buf, format="PNG")
#     img_b64 = base64.b64encode(buf.getvalue()).decode()
#     # Save to MongoDB
#     db["qrcodes"].insert_one({
#         "username": username,
#         "destination": destination,
#         "store": store,
#         "date": date,
#         "time": time,
#         "expire_at": expire_at.isoformat(),
#         "created_at": now.isoformat(),
#         "entrances": entrances,
#         "qr_content": qr_content,
#         "qr_image_base64": img_b64
#     })
#     # Return both base64 image and qr_content (as JSON object)
#     return {
#         "qr_image_base64": img_b64,
#         "expire_at": expire_at.isoformat(),
#         "qr_content": qr_content
#     }


@router.post("/base64-to-image")
def base64_to_image(data: QRBase64ToImageRequest):
    """
    Convert a base64-encoded image string to an actual PNG image and return as image stream.
    """
    try:
        img_data = base64.b64decode(data.qr_image_base64)
        return StreamingResponse(io.BytesIO(img_data), media_type="image/png")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 image data.")


@router.get("/list")
def list_qrcodes(username: str = Query(..., description="Username to query")):
    """
    List all QR codes generated by the user, including their status (valid/expired).
    Each record contains the base64 string of the QR code image.
    """
    qrcodes = list(db["qrcodes"].find({"username": username}))
    now = datetime.now(timezone.utc)
    result = []
    for qr in qrcodes:
        expire_at = qr.get("expire_at")
        try:
            expire_at_dt = datetime.fromisoformat(expire_at)
        except Exception:
            expire_at_dt = None
        status = "valid" if expire_at_dt and now < expire_at_dt else "expired"
        # get QR code image base64 from database
        qr_content = qr.get("qr_content")
        img_b64 = qr.get("qr_image_base64")
        # If qr_image_base64 is not stored, generate it from qr_content
        if not img_b64 and qr_content:
            try:
                qr_img = qrcode.make(qr_content)
                buf = io.BytesIO()
                qr_img.save(buf, format="PNG")
                img_b64 = base64.b64encode(buf.getvalue()).decode()
            except Exception:
                img_b64 = None
        result.append(
            {
                "username": qr.get("username"),
                "destination": qr.get("destination"),
                "store": qr.get("store"),
                "date": qr.get("date"),
                "time": qr.get("time"),
                "expire_at": expire_at,
                "created_at": qr.get("created_at"),
                "status": status,
                "entrances": qr.get("entrances"),
                "qr_content": qr_content,
                "qr_image_base64": img_b64,
            }
        )
    return {"qrcodes": result, "total": len(result)}


@router.post("/validate")
def validate_qr(data: QRValidateRequest):
    """
    Validate the QR code content after scanning.
    Checks if required fields exist and if the QR code is still valid.
    All time checks are done in UTC.
    """
    qr = data.qr_content
    required_fields = ["username", "destination", "expire_at"]
    for field in required_fields:
        if field not in qr:
            metrics.record_qr_scan("invalid_missing_field")
            return {"valid": False, "reason": f"Missing required field: {field}"}
    try:
        expire_at_dt = datetime.fromisoformat(qr["expire_at"])
    except Exception:
        metrics.record_qr_scan("invalid_format")
        return {"valid": False, "reason": "Invalid expire_at format."}
    now = datetime.now(timezone.utc)
    if now > expire_at_dt:
        metrics.record_qr_scan("expired")
        return {"valid": False, "reason": "QR code has expired."}
    # Return all fields for reference
    metrics.record_qr_scan("valid", qr.get("building"))
    result = {"valid": True, "reason": "QR code is valid."}
    result.update(qr)
    return result


@router.get(
    "/generate-all-entrance-qrs",
    responses={
        200: {
            "description": "All entrance QR codes generated successfully",
            "content": {
                "application/json": {
                    "example": {
                        "total": 5,
                        "qr_codes": [
                            {
                                "entrance_id": "E1",
                                "building": "ShoppingMall",
                                "level": 1,
                                "coordinates": {"x": 10, "y": 20},
                                "qr_image_base64": "...base64...",
                            }
                        ],
                    }
                }
            },
        }
    },
)
def generate_all_entrance_qrs(
    format_type: str = Query(
        "json", description="Format type of QR codes: 'json', 'simple', or 'param'"
    )
):
    """
    Generate all entrance QR codes

    This endpoint will generate QR codes for all entrances in the system, for printing and deployment purposes.
    It returns a list of all entrance QR codes, each containing the entrance ID, building, level, and coordinates.

    Available format types:
    - json: JSON format, containing complete structured data
    - simple: Simple format, using underscores to separate values
    - param: URL parameter format, using & to connect key-value pairs
    """
    results = []

    # First, get entrances from MongoDB maps
    try:
        mongodb_maps = list(db["maps"].find({}))
        for map_doc in mongodb_maps:
            if "parking_map" in map_doc:
                for map_level in map_doc["parking_map"]:
                    building_name = map_level.get("building")
                    level = map_level.get("level", 1)

                    for entrance in map_level.get("entrances", []):
                        entrance_id = entrance.get("entrance_id")
                        if not entrance_id:
                            continue

                        x = entrance.get("x", 0)
                        y = entrance.get("y", 0)

                        # Process this entrance (same logic as below)
                        qr_content = None
                        if format_type == "json":
                            qr_content = {
                                "entrance_id": entrance_id,
                                "building": building_name,
                                "level": level,
                                "coordinates": {"x": x, "y": y},
                            }
                            qr_string = json.dumps(qr_content)
                        elif format_type == "simple":
                            qr_string = f"ENTRANCE_{building_name}_{entrance_id}_{level}_{x}_{y}"
                            qr_content = qr_string
                        elif format_type == "param":
                            qr_string = f"entrance={entrance_id}&building={building_name}&level={level}&x={x}&y={y}"
                            qr_content = qr_string
                        else:
                            continue

                        # generate QR code image
                        qr = qrcode.make(qr_string)
                        buf = io.BytesIO()
                        qr.save(buf, format="PNG")
                        img_b64 = base64.b64encode(buf.getvalue()).decode()

                        # save to database
                        db["entrance_qrcodes"].insert_one(
                            {
                                "entrance_id": entrance_id,
                                "building": building_name,
                                "level": level,
                                "coordinates": {"x": x, "y": y},
                                "format_type": format_type,
                                "qr_content": qr_content,
                                "qr_image_base64": img_b64,
                                "created_at": datetime.now(timezone.utc).isoformat(),
                            }
                        )

                        # add to results list
                        results.append(
                            {
                                "entrance_id": entrance_id,
                                "building": building_name,
                                "level": level,
                                "coordinates": {"x": x, "y": y},
                                "format_type": format_type,
                                "qr_content": qr_content,
                                "qr_image_base64": img_b64,
                            }
                        )
    except Exception as e:
        print(f"Error processing MongoDB maps: {e}")

    # Also iterate through example_map data to find entrances (as fallback)
    for map_level in example_map:
        building_name = map_level.get("building")
        level = map_level.get("level", 1)

        for entrance in map_level.get("entrances", []):
            entrance_id = entrance.get("entrance_id")
            if not entrance_id:
                continue

            x = entrance.get("x", 0)
            y = entrance.get("y", 0)

            # create QR code content based on format type
            qr_content = None
            if format_type == "json":
                qr_content = {
                    "entrance_id": entrance_id,
                    "building": building_name,
                    "level": level,
                    "coordinates": {"x": x, "y": y},
                }
                qr_string = json.dumps(qr_content)
            elif format_type == "simple":
                qr_string = f"ENTRANCE_{building_name}_{entrance_id}_{level}_{x}_{y}"
                qr_content = qr_string
            elif format_type == "param":
                qr_string = f"entrance={entrance_id}&building={building_name}&level={level}&x={x}&y={y}"
                qr_content = qr_string
            else:
                continue

            # generate QR code image
            qr = qrcode.make(qr_string)
            buf = io.BytesIO()
            qr.save(buf, format="PNG")
            img_b64 = base64.b64encode(buf.getvalue()).decode()

            # save to database
            db["entrance_qrcodes"].insert_one(
                {
                    "entrance_id": entrance_id,
                    "building": building_name,
                    "level": level,
                    "coordinates": {"x": x, "y": y},
                    "format_type": format_type,
                    "qr_content": qr_content,
                    "qr_image_base64": img_b64,
                    "created_at": datetime.now(timezone.utc).isoformat(),
                }
            )

            # add to results list
            results.append(
                {
                    "entrance_id": entrance_id,
                    "building": building_name,
                    "level": level,
                    "coordinates": {"x": x, "y": y},
                    "format_type": format_type,
                    "qr_content": qr_content,
                    "qr_image_base64": img_b64,
                }
            )

    return {"total": len(results), "qr_codes": results}
