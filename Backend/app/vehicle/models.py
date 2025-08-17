from pydantic import BaseModel


class Vehicle(BaseModel):
    vehicle_id: str
    plate_number: str
    user_id: str
