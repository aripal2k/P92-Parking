from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime
from enum import Enum


class SubscriptionPlan(str, Enum):
    BASIC = "basic"
    PREMIUM = "premium"


class SubscriptionStatus(str, Enum):
    ACTIVE = "active"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


class SubscriptionUpgradeRequest(BaseModel):
    email: EmailStr


class SubscriptionStatusResponse(BaseModel):
    subscription_plan: SubscriptionPlan
    status: SubscriptionStatus
    expires_at: Optional[datetime] = None
    days_remaining: Optional[int] = None


class SubscriptionUpgradeResponse(BaseModel):
    success: bool
    message: str
    new_plan: SubscriptionPlan
    expires_at: datetime
    amount_charged: float
