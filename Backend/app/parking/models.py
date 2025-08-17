from pydantic import BaseModel, Field
from typing import Optional, List, Tuple, Dict, Any
from datetime import datetime
import uuid


class ParkingSlot(BaseModel):
    slot_id: str  # unique slot id
    level: int  # level of the parking slot
    status: str  # "free", "occupied", "allocated"
    x: float  # x coordinary
    y: float  # y coordinary
    vehicle_id: Optional[str] = None  # current occupied vehicle id
    reserved_by: Optional[str] = None  # reserved user id

    @property
    def color(self):
        if self.status == "free":
            return "green"
        elif self.status == "occupied":
            return "red"
        elif self.status == "allocated":
            return "yellow"
        else:
            return "grey"


class Level(BaseModel):
    level: int
    slots: List[ParkingSlot]


class Entrance(BaseModel):
    entrance_id: str
    level: int
    x: float
    y: float
    type: str = "car"


class Exit(BaseModel):
    exit_id: str
    level: int
    x: float
    y: float


class RoadNode(BaseModel):
    node_id: str
    level: int
    x: float
    y: float
    connected_to: List[str]


class Corridor(BaseModel):
    corridor_id: str
    level: int
    points: List[Tuple[float, float]]
    direction: str = "both"  # "both", "forward", "backward"


class Wall(BaseModel):
    wall_id: str
    level: int
    points: List[Tuple[float, float]]


class Ramp(BaseModel):
    ramp_id: str
    level: int
    x: float
    y: float
    to_level: int
    to_x: float
    to_y: float
    direction: str = "both"  # "up", "down", "both"


class MapSize(BaseModel):
    rows: int
    cols: int


class ParkingMapLevel(BaseModel):
    building: str
    level: int
    size: MapSize
    entrances: List[Entrance]
    exits: List[Exit]
    slots: List[ParkingSlot]
    corridors: Optional[List[Corridor]] = []
    walls: Optional[List[Wall]] = []
    ramps: Optional[List[Ramp]] = []


class ParkingImageAnalysis(BaseModel):
    """
    Parking lot image analysis record
    """

    analysis_id: str = Field(default_factory=lambda: str(uuid.uuid4()), alias="_id")
    original_filename: str
    building_name: str
    image_path: str  # Path to stored image in examples folder
    analysis_timestamp: datetime = Field(default_factory=datetime.utcnow)
    gpt4o_analysis: Dict[str, Any]
    parking_map: List[Dict[str, Any]]
    validation_result: Dict[str, Any]
    grid_size: Dict[str, int]
    file_size: int
    analysis_engine: str = "GPT-4o Vision"

    class Config:
        allow_population_by_field_name = True
        json_encoders = {datetime: lambda v: v.isoformat()}


class ParkingFareRequest(BaseModel):
    """
    Request model for parking fare prediction
    """

    destination: str = Field(..., description="Parking destination/building name")
    date: Optional[str] = Field(
        default=None,
        pattern=r"^\d{4}-\d{2}-\d{2}$",
        description="Date in YYYY-MM-DD format (optional)",
        example="2024-07-16",
    )
    time: Optional[str] = Field(
        default=None,
        pattern=r"^\d{2}:\d{2}$",
        description="Time in HH:MM format (optional)",
        example="14:30",
    )
    duration_hours: float = Field(
        default=2.0,
        gt=0,
        le=24,
        description="Parking duration in hours (defaults to 2 hours)",
    )


class ParkingFareResponse(BaseModel):
    """
    Response model for parking fare calculation
    """

    destination: str
    parking_date: str = Field(..., description="Parking date in YYYY-MM-DD format")
    parking_start_time: str = Field(
        ..., description="Parking start time in HH:MM format"
    )
    parking_end_time: str = Field(..., description="Parking end time in HH:MM format")
    duration_hours: float
    breakdown: Dict[str, float] = Field(
        ..., description="Fare breakdown with all amounts"
    )
    currency: str = Field(default="AUD", description="Currency code")

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}


class DestinationRates(BaseModel):
    """
    Parking rates for a specific destination
    """

    base_rate_per_hour: float = Field(default=0.0, ge=0.0)
    peak_hour_surcharge_rate: float = Field(default=0.0, ge=0.0)
    weekend_surcharge_rate: float = Field(default=0.0, ge=0.0)
    public_holiday_surcharge_rate: float = Field(default=0.0, ge=0.0)


class PeakHourTime(BaseModel):
    """
    Peak hour time range
    """

    start: str = Field(
        ..., pattern=r"^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$"
    )  # HH:MM format
    end: str = Field(..., pattern=r"^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$")  # HH:MM format


class WeekdayPeakHours(BaseModel):
    """
    Weekday peak hours (morning and evening)
    """

    morning: PeakHourTime
    evening: PeakHourTime


class PeakHours(BaseModel):
    """
    Peak hours configuration
    """

    weekday: WeekdayPeakHours


class ParkingRatesConfig(BaseModel):
    """
    Complete parking rates configuration stored in MongoDB
    """

    config_id: str = Field(
        default="default", description="Configuration ID - typically 'default'"
    )
    currency: str = Field(default="AUD")
    default_rates: DestinationRates
    destinations: Dict[str, DestinationRates] = Field(default_factory=dict)
    peak_hours: PeakHours
    public_holidays: List[str] = Field(
        default_factory=list,
        description="List of public holiday dates in YYYY-MM-DD format",
    )
    last_updated: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}
