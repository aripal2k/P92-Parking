from pydantic import BaseModel
from datetime import datetime


class Reservation(BaseModel):
    reservation_id: str
    slot_id: str
    user_id: str
    start_time: datetime
    end_time: datetime
    status: str  # "active", "cancelled", "completed"
