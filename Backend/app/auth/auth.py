from pydantic import BaseModel, EmailStr, field_validator, model_validator
import re
from typing import Optional
from datetime import datetime

# Top 5 most common passwords referenced from:
# https://www.passwordmanager.com/most-common-passwords-latest-statistics/
COMMON_PASSWORDS = {
    "123456",
    "123456789",
    "qwerty",
    "password",
    "12345678",
}


class User(BaseModel):
    email: EmailStr
    username: str
    password: str
    fullname: str
    role: str = "user"
    address: Optional[str] = None
    current_session_id: Optional[str] = None  # parking session field
    subscription_plan: str = "basic"  # default subscription plan
    subscription_expires_at: Optional[datetime] = None  # subscription expiry time


class UserCreate(BaseModel):
    fullname: str
    email: EmailStr
    username: str
    password: str
    confirm_password: str


class OTPVerificationRequest(BaseModel):
    email: EmailStr
    otp: str


class Admin(User):
    role: str = "admin"


class AdminCreate(BaseModel):
    email: EmailStr
    username: str
    password: str
    confirm_password: str
    role: str = "admin"


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class ChangePasswordRequest(BaseModel):
    email: EmailStr
    current_password: str
    new_password: str
    confirm_new_password: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetOTPVerificationRequest(BaseModel):
    email: EmailStr
    otp: str


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    # otp: str
    new_password: str
    confirm_new_password: str


class DeleteAccountRequest(BaseModel):
    email: EmailStr
    password: str


class UserEdit(BaseModel):
    email: EmailStr
    fullname: str = None
    username: str = None
    license_plate: str = None
    phone_number: str = None
    address: str = None


class AdminEdit(BaseModel):
    keyID: str
    current_username: str
    current_password: str
    new_username: str


class AdminChangePassword(BaseModel):
    keyID: str
    current_username: str
    current_password: str
    new_password: str
    confirm_new_password: str


class AdminSlotStatusUpdate(BaseModel):
    keyID: str
    username: str
    password: str
    slot_id: str
    new_status: str
    vehicle_id: str = None
    reserved_by: str = None
    building_name: str = None
    map_id: str = None
    level: int = None

    @field_validator("new_status")
    @classmethod
    def validate_status(cls, v):
        valid_statuses = ["available", "occupied", "allocated"]
        if v not in valid_statuses:
            raise ValueError(f"Status must be one of: {', '.join(valid_statuses)}")
        return v

    @model_validator(mode="after")
    def validate_reserved_by_username(self):
        """Validate that reserved_by contains a valid username when status requires it"""
        if self.new_status in ["occupied", "allocated"]:
            if not self.reserved_by:
                raise ValueError(
                    f"reserved_by is required when status is '{self.new_status}'"
                )

            # Import here to avoid circular imports
            from app.database import user_collection

            # Check if username exists and is a regular user (not admin)
            user = user_collection.find_one(
                {"username": self.reserved_by, "role": "user"}
            )

            if not user:
                raise ValueError(
                    f"Username '{self.reserved_by}' not found or is not a valid user"
                )

        return self
