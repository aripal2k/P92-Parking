from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ParkingSession(BaseModel):
    session_id: str
    slot_id: str
    vehicle_id: str
    user_id: str
    start_time: datetime
    end_time: Optional[datetime] = None
    entrance_id: str
    exit_id: str
