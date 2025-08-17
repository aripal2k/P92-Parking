from fastapi import APIRouter, HTTPException, Query
from datetime import datetime, timedelta
import logging
from typing import Dict, Any

from .models import (
    SubscriptionUpgradeRequest,
    SubscriptionStatusResponse,
    SubscriptionUpgradeResponse,
    SubscriptionPlan,
    SubscriptionStatus,
)
from app.database import user_collection, transactions_collection
from app.wallet.models import TransactionType, TransactionStatus
from app.wallet.utils import has_sufficient_balance, deduct_from_wallet

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/subscription", tags=["subscription"])

# Premium subscription pricing configuration
PREMIUM_MONTHLY_PRICE = 20.0  # $20 AUD per month


@router.get(
    "/status",
    response_model=SubscriptionStatusResponse,
    summary="Get Subscription Status",
    description="Get current subscription status for a user",
    responses={
        200: {
            "description": "Subscription status retrieved successfully",
            "content": {
                "application/json": {
                    "example": {
                        "subscription_plan": "premium",
                        "status": "active",
                        "expires_at": "2024-08-15T10:00:00Z",
                        "days_remaining": 15,
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
def get_subscription_status(email: str = Query(..., description="User email address")):
    """Get current subscription status for a user"""
    email = email.strip().lower()
    logger.info(f"Getting subscription status for user: {email}")

    # Find user
    user_doc = user_collection.find_one({"email": email})
    if not user_doc:
        raise HTTPException(status_code=404, detail="User not found")

    subscription_plan = user_doc.get("subscription_plan", "basic")
    expires_at = user_doc.get("subscription_expires_at")

    # Determine subscription status
    status = SubscriptionStatus.ACTIVE
    days_remaining = None

    if subscription_plan == "premium":
        if expires_at:
            current_time = datetime.utcnow()
            if expires_at <= current_time:
                status = SubscriptionStatus.EXPIRED
                # If expired, automatically downgrade to basic
                user_collection.update_one(
                    {"email": email}, {"$set": {"subscription_plan": "basic"}}
                )
                subscription_plan = "basic"
            else:
                days_remaining = (expires_at - current_time).days

    return SubscriptionStatusResponse(
        subscription_plan=subscription_plan,
        status=status,
        expires_at=expires_at,
        days_remaining=days_remaining,
    )


@router.post(
    "/upgrade",
    response_model=SubscriptionUpgradeResponse,
    summary="Upgrade to Premium Subscription",
    description="Upgrade user to premium subscription by deducting from wallet balance",
    responses={
        200: {
            "description": "Successfully upgraded to premium",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "Successfully upgraded to premium subscription",
                        "new_plan": "premium",
                        "expires_at": "2024-08-15T10:00:00Z",
                        "amount_charged": 20.0,
                    }
                }
            },
        },
        400: {
            "description": "Insufficient balance or already premium",
            "content": {
                "application/json": {
                    "examples": {
                        "InsufficientBalance": {
                            "summary": "Insufficient wallet balance",
                            "value": {
                                "detail": "Insufficient wallet balance. Need $20.00 but only have $15.50"
                            },
                        },
                        "AlreadyPremium": {
                            "summary": "Already premium member",
                            "value": {"detail": "User is already a premium member"},
                        },
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
def upgrade_subscription(request: SubscriptionUpgradeRequest):
    """Upgrade user to premium subscription"""
    email = request.email.strip().lower()
    logger.info(f"Processing subscription upgrade for user: {email}")

    # Verify user exists
    user_doc = user_collection.find_one({"email": email})
    if not user_doc:
        raise HTTPException(status_code=404, detail="User not found")

    current_plan = user_doc.get("subscription_plan", "basic")
    expires_at = user_doc.get("subscription_expires_at")

    # Check if already premium and not expired
    if current_plan == "premium" and expires_at and expires_at > datetime.utcnow():
        raise HTTPException(status_code=400, detail="User is already a premium member")

    # Check wallet balance
    if not has_sufficient_balance(email, PREMIUM_MONTHLY_PRICE):
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient wallet balance. Need ${PREMIUM_MONTHLY_PRICE:.2f}",
        )

    try:
        # Deduct from wallet
        deduct_result = deduct_from_wallet(
            email=email,
            amount=PREMIUM_MONTHLY_PRICE,
            description="Premium subscription upgrade",
            metadata={
                "subscription_type": "premium",
                "duration_months": 1,
                "upgrade_date": datetime.utcnow().isoformat(),
            },
        )

        # Calculate new expiry time (1 month from now)
        new_expires_at = datetime.utcnow() + timedelta(days=30)

        # Update user subscription information
        user_collection.update_one(
            {"email": email},
            {
                "$set": {
                    "subscription_plan": "premium",
                    "subscription_expires_at": new_expires_at,
                }
            },
        )

        logger.info(f"Successfully upgraded user {email} to premium subscription")

        return SubscriptionUpgradeResponse(
            success=True,
            message="Successfully upgraded to premium subscription",
            new_plan=SubscriptionPlan.PREMIUM,
            expires_at=new_expires_at,
            amount_charged=PREMIUM_MONTHLY_PRICE,
        )

    except Exception as e:
        logger.error(f"Failed to upgrade subscription for {email}: {str(e)}")
        raise HTTPException(
            status_code=500, detail="Failed to process subscription upgrade"
        )


@router.get(
    "/pricing",
    summary="Get Subscription Pricing",
    description="Get current subscription pricing information",
)
def get_subscription_pricing():
    """Get subscription pricing information"""
    return {
        "premium_monthly_price": PREMIUM_MONTHLY_PRICE,
        "currency": "AUD",
        "benefits": [
            "Up to 3 pending payments (vs 1 for basic)",
            "Choose any available parking slot on map",
            "Custom pathfinding to selected slots",
        ],
    }
