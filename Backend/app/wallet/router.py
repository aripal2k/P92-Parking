from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
from datetime import datetime
import logging
import hashlib
import secrets
from app.wallet.models import (
    AddMoneyRequest,
    CreatePaymentMethodRequest,
    UpdatePaymentMethodRequest,
    WalletBalanceResponse,
    TransactionResponse,
    PaymentMethod,
    WalletBalance,
    Transaction,
    TransactionStatus,
    TransactionType,
    PaymentMethodType,
)
from app.database import user_collection, db
from app.cloudwatch_metrics import metrics
from app.parking.storage import storage_manager
from luhncheck import is_luhn

router = APIRouter(prefix="/wallet", tags=["wallet"])

# Database collections
wallet_collection = db["wallets"]
payment_methods_collection = db["payment_methods"]
transactions_collection = db["transactions"]

logger = logging.getLogger(__name__)


def verify_user_exists(email: str) -> bool:
    """Verify that the user exists in the system"""
    email = email.strip().lower()
    user = user_collection.find_one({"email": email, "role": "user"})
    return user is not None


def encrypt_card_number(card_number: str) -> str:
    """Simple encryption for demo purposes - in production use proper encryption"""
    # Remove spaces and get last 4 digits
    clean_number = card_number.replace(" ", "").replace("-", "")
    last_four = clean_number[-4:]
    # Create a hash for the full number (one-way)
    hashed = hashlib.sha256(
        f"{clean_number}_{secrets.token_hex(16)}".encode()
    ).hexdigest()[:16]
    return f"****-****-****-{last_four}"


def get_or_create_wallet(email: str) -> WalletBalance:
    """Get existing wallet or create new one with zero balance"""
    email = email.strip().lower()

    wallet = wallet_collection.find_one({"user_email": email})
    if wallet:
        return WalletBalance(**wallet)

    # Create new wallet
    new_wallet = WalletBalance(user_email=email, balance=0.0)
    wallet_collection.insert_one(new_wallet.model_dump())
    logger.info(f"Created new wallet for user: {email}")
    return new_wallet


@router.get(
    "/balance",
    response_model=WalletBalanceResponse,
    summary="Get Wallet Balance",
    description="Get the current wallet balance for a user",
    responses={
        200: {
            "description": "Wallet balance retrieved successfully",
            "content": {
                "application/json": {
                    "example": {
                        "balance": 25.50,
                        "currency": "AUD",
                        "last_updated": "2024-01-15T10:30:00Z",
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
def get_wallet_balance(email: str = Query(..., description="User email address")):
    """Get the current wallet balance for a user"""
    email = email.strip().lower()
    logger.info(f"Fetching wallet balance for user: {email}")

    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    wallet = get_or_create_wallet(email)

    return WalletBalanceResponse(
        balance=wallet.balance,
        currency=wallet.currency,
        last_updated=wallet.last_updated,
    )


@router.post(
    "/add-money",
    response_model=TransactionResponse,
    summary="Add Money to Wallet",
    description="Add money to user's wallet using a payment method",
    responses={
        200: {
            "description": "Money added successfully",
            "content": {
                "application/json": {
                    "example": {
                        "transaction_id": "12345678-1234-5678-9abc-123456789012",
                        "transaction_type": "add_money",
                        "amount": 50.00,
                        "currency": "AUD",
                        "status": "completed",
                        "description": "Add money to wallet",
                        "created_at": "2024-01-15T10:30:00Z",
                        "completed_at": "2024-01-15T10:30:05Z",
                    }
                }
            },
        },
        400: {
            "description": "Invalid request or payment method",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidAmount": {
                            "summary": "Invalid amount",
                            "value": {
                                "detail": "Amount must be greater than 0 and less than $1000"
                            },
                        },
                        "PaymentMethodNotFound": {
                            "summary": "Payment method not found",
                            "value": {"detail": "Payment method not found"},
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
def add_money_to_wallet(request: AddMoneyRequest):
    """Add money to user's wallet"""
    email = request.email.strip().lower()
    logger.info(f"Adding ${request.amount} to wallet for user: {email}")

    # Verify user exists
    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    # Verify payment method exists and belongs to user
    payment_method = payment_methods_collection.find_one(
        {
            "payment_method_id": request.payment_method_id,
            "user_email": email,
            "is_active": True,
        }
    )

    if not payment_method:
        raise HTTPException(
            status_code=400, detail="Payment method not found or inactive"
        )

    # Create transaction record
    transaction = Transaction(
        user_email=email,
        transaction_type=TransactionType.ADD_MONEY,
        amount=request.amount,
        payment_method_id=request.payment_method_id,
        description="Add money to wallet",
        status=TransactionStatus.PENDING,
    )

    try:
        # Insert transaction
        transactions_collection.insert_one(transaction.model_dump())

        # Simulate payment processing

        # Update wallet balance
        wallet = get_or_create_wallet(email)
        new_balance = wallet.balance + request.amount

        wallet_collection.update_one(
            {"user_email": email},
            {"$set": {"balance": new_balance, "last_updated": datetime.utcnow()}},
        )

        # Mark transaction as completed
        completed_at = datetime.utcnow()
        transactions_collection.update_one(
            {"transaction_id": transaction.transaction_id},
            {
                "$set": {
                    "status": TransactionStatus.COMPLETED,
                    "completed_at": completed_at,
                }
            },
        )

        # Record metrics
        metrics.record_revenue(request.amount, "wallet_topup")
        metrics.increment_counter("WalletOperations", {"operation": "add_money"})

        logger.info(f"Successfully added ${request.amount} to wallet for user: {email}")

        return TransactionResponse(
            transaction_id=transaction.transaction_id,
            transaction_type=transaction.transaction_type,
            amount=transaction.amount,
            currency=transaction.currency,
            status=TransactionStatus.COMPLETED,
            description=transaction.description,
            created_at=transaction.created_at,
            completed_at=completed_at,
        )

    except Exception as e:
        logger.error(f"Failed to add money to wallet for user {email}: {str(e)}")
        # Mark transaction as failed
        transactions_collection.update_one(
            {"transaction_id": transaction.transaction_id},
            {"$set": {"status": TransactionStatus.FAILED}},
        )
        raise HTTPException(status_code=500, detail="Failed to process payment")


@router.post(
    "/test-add-money",
    response_model=TransactionResponse,
    summary="Test Add Money to Wallet",
    description="Add money to user's wallet for testing purposes - bypasses payment method requirement",
    responses={
        200: {
            "description": "Test money added successfully",
            "content": {
                "application/json": {
                    "example": {
                        "transaction_id": "12345678-1234-5678-9abc-123456789012",
                        "transaction_type": "add_money",
                        "amount": 50.00,
                        "currency": "AUD",
                        "status": "completed",
                        "description": "Test balance addition",
                        "created_at": "2024-01-15T10:30:00Z",
                        "completed_at": "2024-01-15T10:30:05Z",
                    }
                }
            },
        },
        400: {
            "description": "Invalid request",
            "content": {
                "application/json": {
                    "example": {
                        "detail": "Amount must be greater than 0 and less than $1000"
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
def test_add_money_to_wallet(
    email: str = Query(..., description="User email"),
    amount: float = Query(..., description="Amount to add", gt=0, le=1000),
    description: str = Query(
        "Test balance addition", description="Transaction description"
    ),
):
    """Add money to user's wallet for testing purposes"""
    email = email.strip().lower()
    logger.info(f"Test adding ${amount} to wallet for user: {email}")

    # Verify user exists
    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    # Create transaction record
    transaction = Transaction(
        user_email=email,
        transaction_type=TransactionType.ADD_MONEY,
        amount=amount,
        payment_method_id=None,  # No payment method for test
        description=description,
        status=TransactionStatus.PENDING,
    )

    try:
        # Insert transaction
        transactions_collection.insert_one(transaction.model_dump())

        # Update wallet balance directly (test mode)
        wallet = get_or_create_wallet(email)
        new_balance = wallet.balance + amount

        wallet_collection.update_one(
            {"user_email": email},
            {"$set": {"balance": new_balance, "last_updated": datetime.utcnow()}},
        )

        # Mark transaction as completed
        completed_at = datetime.utcnow()
        transactions_collection.update_one(
            {"transaction_id": transaction.transaction_id},
            {
                "$set": {
                    "status": TransactionStatus.COMPLETED,
                    "completed_at": completed_at,
                }
            },
        )

        # Record metrics
        metrics.record_revenue(amount, "test_wallet_topup")
        metrics.increment_counter("WalletOperations", {"operation": "test_add_money"})

        logger.info(f"Successfully test added ${amount} to wallet for user: {email}")

        return TransactionResponse(
            transaction_id=transaction.transaction_id,
            transaction_type=transaction.transaction_type,
            amount=transaction.amount,
            currency=transaction.currency,
            status=TransactionStatus.COMPLETED,
            description=transaction.description,
            created_at=transaction.created_at,
            completed_at=completed_at,
        )

    except Exception as e:
        logger.error(f"Failed to test add money to wallet for user {email}: {str(e)}")
        # Mark transaction as failed
        transactions_collection.update_one(
            {"transaction_id": transaction.transaction_id},
            {"$set": {"status": TransactionStatus.FAILED}},
        )
        raise HTTPException(status_code=500, detail="Failed to process test payment")


@router.post(
    "/pay-parking",
    response_model=TransactionResponse,
    summary="Pay for Parking",
    description="Pay for parking using wallet balance",
    responses={
        200: {
            "description": "Parking payment successful",
            "content": {
                "application/json": {
                    "example": {
                        "transaction_id": "12345678-1234-5678-9abc-123456789012",
                        "transaction_type": "parking_payment",
                        "amount": 15.50,
                        "currency": "AUD",
                        "status": "completed",
                        "description": "Parking fee payment",
                        "created_at": "2024-01-15T10:30:00Z",
                        "completed_at": "2024-01-15T10:30:05Z",
                    }
                }
            },
        },
        400: {
            "description": "Insufficient balance or invalid amount",
            "content": {
                "application/json": {
                    "examples": {
                        "InsufficientBalance": {
                            "summary": "Not enough money in wallet",
                            "value": {
                                "detail": "Insufficient balance. Current: $5.00, Required: $15.50"
                            },
                        },
                        "InvalidAmount": {
                            "summary": "Invalid payment amount",
                            "value": {"detail": "Amount must be greater than 0"},
                        },
                    }
                }
            },
        },
        404: {
            "description": "User not found",
            "content": {
                "application/json": {
                    "examples": {
                        "UserNotFound": {
                            "summary": "User not found",
                            "value": {"detail": "User not found"},
                        }
                    }
                }
            },
        },
    },
)
def pay_parking_fee(
    email: str = Query(..., description="User email address"),
    amount: float = Query(..., gt=0, description="Parking fee amount"),
    slot_id: str = Query(..., description="Parking slot ID"),
    session_id: Optional[str] = Query(None, description="Parking session ID"),
    building_name: Optional[str] = Query(None, description="Building name"),
):
    """Pay for parking using wallet balance"""
    email = email.strip().lower()
    logger.info(f"Processing parking payment of ${amount} for user: {email}")

    # Verify user exists
    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    # 📝 Status check removed: Allow payment for completed parking sessions
    # regardless of current slot status (user should be able to pay for past usage)
    logger.info(
        f"Processing payment for slot {slot_id} (status check bypassed for completed sessions)"
    )

    # Get wallet balance
    wallet = get_or_create_wallet(email)

    # Check if user has sufficient balance
    if wallet.balance < amount:
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient balance. Current: ${wallet.balance:.2f}, Required: ${amount:.2f}",
        )

    # Create transaction record
    metadata = {
        "slot_id": slot_id,
        "building_name": building_name,
        "session_id": session_id,
    }

    transaction = Transaction(
        user_email=email,
        transaction_type=TransactionType.PARKING_PAYMENT,
        amount=amount,
        description=f"Parking fee payment for slot {slot_id}",
        status=TransactionStatus.PENDING,
        metadata=metadata,
    )

    try:
        # Insert transaction
        transactions_collection.insert_one(transaction.model_dump())

        # Update wallet balance
        new_balance = wallet.balance - amount

        wallet_collection.update_one(
            {"user_email": email},
            {"$set": {"balance": new_balance, "last_updated": datetime.utcnow()}},
        )

        # Mark transaction as completed
        completed_at = datetime.utcnow()
        transactions_collection.update_one(
            {"transaction_id": transaction.transaction_id},
            {
                "$set": {
                    "status": TransactionStatus.COMPLETED,
                    "completed_at": completed_at,
                }
            },
        )

        # Record metrics
        metrics.record_revenue(amount, "parking_payment")
        metrics.increment_counter("WalletOperations", {"operation": "parking_payment"})

        logger.info(
            f"Successfully processed parking payment of ${amount} for user: {email}"
        )

        return TransactionResponse(
            transaction_id=transaction.transaction_id,
            transaction_type=transaction.transaction_type,
            amount=transaction.amount,
            currency=transaction.currency,
            status=TransactionStatus.COMPLETED,
            description=transaction.description,
            created_at=transaction.created_at,
            completed_at=completed_at,
        )

    except Exception as e:
        logger.error(f"Failed to process parking payment for user {email}: {str(e)}")
        # Mark transaction as failed
        transactions_collection.update_one(
            {"transaction_id": transaction.transaction_id},
            {"$set": {"status": TransactionStatus.FAILED}},
        )
        raise HTTPException(status_code=500, detail="Failed to process parking payment")


@router.post(
    "/payment-methods",
    response_model=dict,
    summary="Add Payment Method",
    description="Add a new payment method to user's account",
    responses={
        201: {
            "description": "Payment method added successfully",
            "content": {
                "application/json": {
                    "example": {
                        "msg": "Payment method added successfully",
                        "payment_method_id": "12345678-1234-5678-9abc-123456789012",
                    }
                }
            },
        },
        400: {
            "description": "Invalid payment method data",
            "content": {
                "application/json": {
                    "example": {"detail": "Invalid card number format"}
                }
            },
        },
        404: {
            "description": "User not found",
            "content": {"application/json": {"example": {"detail": "User not found"}}},
        },
    },
)
def add_payment_method(request: CreatePaymentMethodRequest):
    """Add a new payment method"""
    email = request.email.strip().lower()
    logger.info(f"Adding payment method for user: {email}")

    # Verify user exists
    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    # If this is set as default, unset others
    if request.is_default:
        payment_methods_collection.update_many(
            {"user_email": email}, {"$set": {"is_default": False}}
        )

    # Create payment method (encrypt card number)
    encrypted_display = encrypt_card_number(request.card_number)
    last_four = request.card_number.replace(" ", "").replace("-", "")[-4:]

    payment_method = PaymentMethod(
        user_email=email,
        method_type=request.method_type,
        username=request.username,
        cardholder_name=request.cardholder_name,
        last_four_digits=last_four,
        expiry_month=request.expiry_month,
        expiry_year=request.expiry_year,
        is_default=request.is_default,
    )

    # Insert payment method
    payment_methods_collection.insert_one(payment_method.model_dump())

    metrics.increment_counter("WalletOperations", {"operation": "add_payment_method"})

    logger.info(f"Payment method added successfully for user: {email}")

    return {
        "msg": "Payment method added successfully",
        "payment_method_id": payment_method.payment_method_id,
    }


@router.get(
    "/payment-methods",
    response_model=List[dict],
    summary="Get Payment Methods",
    description="Get all payment methods for a user",
    responses={
        200: {
            "description": "Payment methods retrieved successfully",
            "content": {
                "application/json": {
                    "example": [
                        {
                            "payment_method_id": "12345678-1234-5678-9abc-123456789012",
                            "method_type": "credit_card",
                            "username": "Visa ending in 1234",
                            "cardholder_name": "John Doe",
                            "last_four_digits": "1234",
                            "expiry_month": "12",
                            "expiry_year": 2026,
                            "is_default": True,
                            "is_active": True,
                            "created_at": "2025-01-15T10:30:00Z",
                        }
                    ]
                }
            },
        },
        404: {
            "description": "User not found",
            "content": {"application/json": {"example": {"detail": "User not found"}}},
        },
    },
)
def get_payment_methods(email: str = Query(..., description="User email address")):
    """Get all payment methods for a user"""
    email = email.strip().lower()
    logger.info(f"Fetching payment methods for user: {email}")

    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    payment_methods = list(
        payment_methods_collection.find(
            {"user_email": email, "is_active": True},
            {"_id": 0},  # Exclude MongoDB _id field
        )
    )

    return payment_methods


@router.put(
    "/payment-methods/{payment_method_id}",
    response_model=dict,
    summary="Update Payment Method",
    description="Update an existing payment method",
    responses={
        200: {
            "description": "Payment method updated successfully",
            "content": {
                "application/json": {
                    "example": {"msg": "Payment method updated successfully"}
                }
            },
        },
        400: {
            "description": "Invalid update data",
            "content": {
                "application/json": {"example": {"detail": "No fields to update"}}
            },
        },
        404: {
            "description": "Payment method not found",
            "content": {
                "application/json": {"example": {"detail": "Payment method not found"}}
            },
        },
    },
)
def update_payment_method(payment_method_id: str, request: UpdatePaymentMethodRequest):
    """Update an existing payment method"""
    email = request.email.strip().lower()
    logger.info(f"Updating payment method {payment_method_id} for user: {email}")

    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    # Build update fields
    update_fields = {"updated_at": datetime.utcnow()}

    if request.expiry_month is not None:
        update_fields["expiry_month"] = request.expiry_month
    if request.expiry_year is not None:
        update_fields["expiry_year"] = request.expiry_year
    if request.is_active is not None:
        update_fields["is_active"] = request.is_active
    if request.is_default is not None:
        # If setting as default, unset others first
        if request.is_default:
            payment_methods_collection.update_many(
                {"user_email": email}, {"$set": {"is_default": False}}
            )
        update_fields["is_default"] = request.is_default

    if len(update_fields) == 1:  # Only updated_at
        raise HTTPException(status_code=400, detail="No fields to update")

    # Update payment method
    result = payment_methods_collection.update_one(
        {"payment_method_id": payment_method_id, "user_email": email},
        {"$set": update_fields},
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Payment method not found")

    metrics.increment_counter(
        "WalletOperations", {"operation": "update_payment_method"}
    )

    return {"msg": "Payment method updated successfully"}


@router.delete(
    "/payment-methods/{payment_method_id}",
    response_model=dict,
    summary="Delete Payment Method",
    description="Delete a payment method",
    responses={
        200: {
            "description": "Payment method deleted successfully",
            "content": {
                "application/json": {
                    "example": {"msg": "Payment method deleted successfully"}
                }
            },
        },
        404: {
            "description": "Payment method not found",
            "content": {
                "application/json": {"example": {"detail": "Payment method not found"}}
            },
        },
    },
)
def delete_payment_method(
    payment_method_id: str, email: str = Query(..., description="User email address")
):
    """Delete a payment method"""
    email = email.strip().lower()
    logger.info(f"Deleting payment method {payment_method_id} for user: {email}")

    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    # Soft delete by setting inactive
    result = payment_methods_collection.update_one(
        {"payment_method_id": payment_method_id, "user_email": email},
        {
            "$set": {
                "is_active": False,
                "is_default": False,
                "updated_at": datetime.utcnow(),
            }
        },
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Payment method not found")

    metrics.increment_counter(
        "WalletOperations", {"operation": "delete_payment_method"}
    )

    return {"msg": "Payment method deleted successfully"}


@router.get(
    "/transactions",
    response_model=List[TransactionResponse],
    summary="Get Transaction History",
    description="Get transaction history for a user",
    responses={
        200: {
            "description": "Transaction history retrieved successfully",
            "content": {
                "application/json": {
                    "example": [
                        {
                            "transaction_id": "12345678-1234-5678-9abc-123456789012",
                            "transaction_type": "add_money",
                            "amount": 50.00,
                            "currency": "AUD",
                            "status": "completed",
                            "description": "Add money to wallet",
                            "created_at": "2024-01-15T10:30:00Z",
                            "completed_at": "2024-01-15T10:30:05Z",
                        }
                    ]
                }
            },
        },
        404: {
            "description": "User not found",
            "content": {"application/json": {"example": {"detail": "User not found"}}},
        },
    },
)
def get_transaction_history(
    email: str = Query(..., description="User email address"),
    limit: int = Query(
        50, ge=1, le=100, description="Number of transactions to return"
    ),
    offset: int = Query(0, ge=0, description="Number of transactions to skip"),
):
    """Get transaction history for a user"""
    email = email.strip().lower()
    logger.info(f"Fetching transaction history for user: {email}")

    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    transactions = list(
        transactions_collection.find(
            {"user_email": email}, {"_id": 0}  # Exclude MongoDB _id field
        )
        .sort("created_at", -1)
        .skip(offset)
        .limit(limit)
    )

    return [TransactionResponse(**transaction) for transaction in transactions]


@router.get(
    "/transactions/{transaction_id}",
    response_model=TransactionResponse,
    summary="Get Transaction Details",
    description="Get details of a specific transaction",
    responses={
        200: {"description": "Transaction details retrieved successfully"},
        404: {
            "description": "Transaction not found",
            "content": {
                "application/json": {"example": {"detail": "Transaction not found"}}
            },
        },
    },
)
def get_transaction_details(
    transaction_id: str, email: str = Query(..., description="User email address")
):
    """Get details of a specific transaction"""
    email = email.strip().lower()
    logger.info(f"Fetching transaction {transaction_id} for user: {email}")

    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    transaction = transactions_collection.find_one(
        {"transaction_id": transaction_id, "user_email": email}, {"_id": 0}
    )

    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")

    return TransactionResponse(**transaction)


@router.post(
    "/pay-later",
    response_model=dict,
    summary="Save Payment for Later",
    description="Save parking payment details for later payment without deducting from wallet",
    responses={
        200: {
            "description": "Payment saved successfully",
            "content": {
                "application/json": {
                    "example": {
                        "success": True,
                        "message": "payment saved to wallet",
                        "transaction_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                        "amount": 2.50,
                        "slot_id": "1A",
                        "building_name": "Westfield Sydney",
                    }
                }
            },
        },
        404: {
            "description": "User not found",
            "content": {"application/json": {"example": {"detail": "User not found"}}},
        },
        422: {
            "description": "Validation error",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidAmount": {
                            "summary": "Invalid amount (negative or zero)",
                            "value": {
                                "detail": [
                                    {
                                        "type": "greater_than",
                                        "loc": ["query", "amount"],
                                        "msg": "Input should be greater than 0",
                                        "input": -5.0,
                                    }
                                ]
                            },
                        },
                        "MissingSlotId": {
                            "summary": "Missing required slot_id",
                            "value": {
                                "detail": [
                                    {
                                        "type": "missing",
                                        "loc": ["query", "slot_id"],
                                        "msg": "Field required",
                                    }
                                ]
                            },
                        },
                    }
                }
            },
        },
        500: {
            "description": "Internal server error",
            "content": {
                "application/json": {"example": {"detail": "Failed to save payment"}}
            },
        },
    },
)
def save_payment_for_later(
    email: str = Query(..., description="User email address"),
    amount: float = Query(..., gt=0, description="Parking fee amount"),
    slot_id: str = Query(..., description="Parking slot ID"),
    session_id: Optional[str] = Query(None, description="Parking session ID"),
    building_name: Optional[str] = Query(None, description="Building name"),
    start_time: Optional[str] = Query(None, description="Parking start time"),
    end_time: Optional[str] = Query(None, description="Parking end time"),
    duration: Optional[str] = Query(None, description="Parking duration"),
):
    """Save parking payment details for later payment"""
    email = email.strip().lower()
    logger.info(
        f"Saving payment for later - ${amount} for user: {email}, slot: {slot_id}"
    )

    # Verify user exists and get subscription plan
    user_doc = user_collection.find_one({"email": email})
    if not user_doc:
        raise HTTPException(status_code=404, detail="User not found")

    # Check subscription plan and existing pending payments
    subscription_plan = user_doc.get("subscription_plan", "basic")
    subscription_expires_at = user_doc.get("subscription_expires_at")

    # Check if premium subscription is still valid
    is_premium_active = False
    if subscription_plan == "premium" and subscription_expires_at:
        from datetime import datetime

        if subscription_expires_at > datetime.utcnow():
            is_premium_active = True
        else:
            # Premium expired, downgrade to basic
            user_collection.update_one(
                {"email": email}, {"$set": {"subscription_plan": "basic"}}
            )
            subscription_plan = "basic"

    # Count existing pending payments for this user
    existing_pending_count = transactions_collection.count_documents(
        {
            "user_email": email,
            "status": TransactionStatus.PENDING,
            "transaction_type": TransactionType.PARKING_PAYMENT,
        }
    )

    # Apply limits based on subscription plan
    if is_premium_active:
        # Premium plan limit for pending payments is 3
        if existing_pending_count >= 3:
            raise HTTPException(
                status_code=400,
                detail="Premium subscription users can have up to 3 pending payments. Please pay some existing pending payments first.",
            )
    else:
        # Basic plan limit for pending payments is 1
        if existing_pending_count >= 1:
            raise HTTPException(
                status_code=400,
                detail="Basic subscription users can only have one pending payment at a time. Please pay your existing pending payment first or upgrade to premium.",
            )

    # Check parking slot exists (optional validation)
    if slot_id:
        slot_info = storage_manager.find_slot_by_id(slot_id)
        if not slot_info:
            logger.warning(
                f"Parking slot '{slot_id}' not found, but allowing pay later anyway"
            )

    # Create pending transaction record with parking details
    metadata = {
        "slot_id": slot_id,
        "building_name": building_name,
        "session_id": session_id,
        "start_time": start_time,
        "end_time": end_time,
        "duration": duration,
        "payment_type": "pay_later",
    }

    transaction = Transaction(
        user_email=email,
        transaction_type=TransactionType.PARKING_PAYMENT,
        amount=amount,
        description=f"Pending parking payment for slot {slot_id}"
        + (f" at {building_name}" if building_name else ""),
        status=TransactionStatus.PENDING,
        metadata=metadata,
    )

    try:
        # Insert pending transaction (don't deduct from wallet yet)
        transactions_collection.insert_one(transaction.model_dump())

        # Record metrics
        metrics.increment_counter("WalletOperations", {"operation": "pay_later"})

        logger.info(
            f"Successfully saved payment for later: {transaction.transaction_id} for user: {email}"
        )

        return {
            "success": True,
            "message": "payment saved to wallet",
            "transaction_id": transaction.transaction_id,
            "amount": amount,
            "slot_id": slot_id,
            "building_name": building_name,
        }

    except Exception as e:
        logger.error(f"Failed to save payment for later for user {email}: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to save payment")


@router.get(
    "/pending-payments",
    response_model=List[TransactionResponse],
    summary="Get Pending Payments",
    description="Get all pending payments for a user to display in wallet",
    responses={
        200: {
            "description": "Pending payments retrieved successfully",
            "content": {
                "application/json": {
                    "examples": {
                        "WithPendingPayments": {
                            "summary": "User has pending payments",
                            "value": [
                                {
                                    "transaction_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                                    "transaction_type": "parking_payment",
                                    "amount": 2.50,
                                    "currency": "AUD",
                                    "status": "pending",
                                    "description": "Pending parking payment for slot 1A at Westfield Sydney",
                                    "created_at": "2025-01-26T19:08:00Z",
                                },
                                {
                                    "transaction_id": "b2c3d4e5-f6g7-8901-bcde-fg2345678901",
                                    "transaction_type": "parking_payment",
                                    "amount": 5.00,
                                    "currency": "AUD",
                                    "status": "pending",
                                    "description": "Pending parking payment for slot 2B at Shopping Center",
                                    "created_at": "2025-01-26T14:30:00Z",
                                },
                            ],
                        },
                        "NoPendingPayments": {
                            "summary": "User has no pending payments",
                            "value": [],
                        },
                    }
                }
            },
        },
        404: {
            "description": "User not found",
            "content": {"application/json": {"example": {"detail": "User not found"}}},
        },
        422: {
            "description": "Validation error",
            "content": {
                "application/json": {
                    "examples": {
                        "InvalidEmail": {
                            "summary": "Invalid email format",
                            "value": {
                                "detail": [
                                    {
                                        "type": "value_error",
                                        "loc": ["query", "email"],
                                        "msg": "value is not a valid email address",
                                        "input": "invalid-email",
                                    }
                                ]
                            },
                        },
                        "InvalidLimit": {
                            "summary": "Invalid limit parameter",
                            "value": {
                                "detail": [
                                    {
                                        "type": "greater_than_equal",
                                        "loc": ["query", "limit"],
                                        "msg": "Input should be greater than or equal to 1",
                                        "input": 0,
                                    }
                                ]
                            },
                        },
                    }
                }
            },
        },
    },
)
def get_pending_payments(
    email: str = Query(..., description="User email address"),
    limit: int = Query(
        50, ge=1, le=100, description="Number of pending payments to return"
    ),
):
    """Get all pending payments for a user"""
    email = email.strip().lower()
    logger.info(f"Fetching pending payments for user: {email}")

    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    pending_payments = list(
        transactions_collection.find(
            {
                "user_email": email,
                "status": TransactionStatus.PENDING,
                "transaction_type": TransactionType.PARKING_PAYMENT,
            },
            {"_id": 0},  # Exclude MongoDB _id field
        )
        .sort("created_at", -1)
        .limit(limit)
    )

    return [TransactionResponse(**payment) for payment in pending_payments]


@router.post(
    "/pay-pending-wallet",
    response_model=TransactionResponse,
    summary="Pay Pending Transaction with Wallet",
    description="Pay a specific pending transaction using wallet balance",
    responses={
        200: {
            "description": "Pending payment processed successfully with wallet",
            "content": {
                "application/json": {
                    "example": {
                        "transaction_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                        "transaction_type": "parking_payment",
                        "amount": 2.50,
                        "currency": "AUD",
                        "status": "completed",
                        "description": "Pending parking payment for slot 1A at Westfield Sydney",
                        "created_at": "2025-01-26T19:08:00Z",
                        "completed_at": "2025-01-26T19:15:23Z",
                    }
                }
            },
        },
        400: {
            "description": "Insufficient balance or invalid transaction",
            "content": {
                "application/json": {
                    "examples": {
                        "InsufficientBalance": {
                            "summary": "Not enough wallet balance",
                            "value": {
                                "detail": "Insufficient balance. Current: $1.50, Required: $2.50"
                            },
                        }
                    }
                }
            },
        },
        404: {
            "description": "User not found or transaction not found",
            "content": {
                "application/json": {
                    "examples": {
                        "UserNotFound": {
                            "summary": "User does not exist",
                            "value": {"detail": "User not found"},
                        },
                        "TransactionNotFound": {
                            "summary": "Pending transaction does not exist",
                            "value": {"detail": "Pending transaction not found"},
                        },
                    }
                }
            },
        },
        422: {
            "description": "Validation error",
            "content": {
                "application/json": {
                    "examples": {
                        "MissingTransactionId": {
                            "summary": "Missing transaction ID",
                            "value": {
                                "detail": [
                                    {
                                        "type": "missing",
                                        "loc": ["query", "transaction_id"],
                                        "msg": "Field required",
                                    }
                                ]
                            },
                        },
                        "InvalidEmail": {
                            "summary": "Invalid email format",
                            "value": {
                                "detail": [
                                    {
                                        "type": "value_error",
                                        "loc": ["query", "email"],
                                        "msg": "value is not a valid email address",
                                        "input": "invalid-email",
                                    }
                                ]
                            },
                        },
                    }
                }
            },
        },
        500: {
            "description": "Internal server error",
            "content": {
                "application/json": {"example": {"detail": "Failed to process payment"}}
            },
        },
    },
)
def pay_pending_transaction_wallet(
    transaction_id: str = Query(..., description="Pending transaction ID to pay"),
    email: str = Query(..., description="User email address"),
):
    """Pay a specific pending transaction using wallet balance"""
    email = email.strip().lower()
    logger.info(
        f"Processing pending payment {transaction_id} with wallet for user: {email}"
    )

    # Verify user exists
    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    # Find the pending transaction
    pending_transaction = transactions_collection.find_one(
        {
            "transaction_id": transaction_id,
            "user_email": email,
            "status": TransactionStatus.PENDING,
        }
    )

    if not pending_transaction:
        raise HTTPException(status_code=404, detail="Pending transaction not found")

    amount = pending_transaction["amount"]

    # Get wallet balance
    wallet = get_or_create_wallet(email)

    # Check if user has sufficient balance
    if wallet.balance < amount:
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient balance. Current: ${wallet.balance:.2f}, Required: ${amount:.2f}",
        )

    try:
        # Update wallet balance
        new_balance = wallet.balance - amount

        wallet_collection.update_one(
            {"user_email": email},
            {"$set": {"balance": new_balance, "last_updated": datetime.utcnow()}},
        )

        # Mark transaction as completed
        completed_at = datetime.utcnow()
        transactions_collection.update_one(
            {"transaction_id": transaction_id},
            {
                "$set": {
                    "status": TransactionStatus.COMPLETED,
                    "completed_at": completed_at,
                    "payment_method": "wallet",
                }
            },
        )

        # Record metrics
        metrics.record_revenue(amount, "pending_payment_wallet")
        metrics.increment_counter(
            "WalletOperations", {"operation": "pay_pending_wallet"}
        )

        logger.info(
            f"Successfully processed pending payment {transaction_id} with wallet for user: {email}"
        )

        # Parse created_at properly
        created_at_value = pending_transaction["created_at"]
        if isinstance(created_at_value, str):
            created_at_parsed = datetime.fromisoformat(
                created_at_value.replace("Z", "+00:00")
            )
        else:
            created_at_parsed = created_at_value

        return TransactionResponse(
            transaction_id=transaction_id,
            transaction_type=TransactionType.PARKING_PAYMENT,
            amount=amount,
            currency="AUD",
            status=TransactionStatus.COMPLETED,
            description=pending_transaction["description"],
            created_at=created_at_parsed,
            completed_at=completed_at,
        )

    except Exception as e:
        logger.error(
            f"Failed to process pending payment {transaction_id} with wallet for user {email}: {str(e)}"
        )
        raise HTTPException(status_code=500, detail="Failed to process payment")


@router.post(
    "/pay-pending-card",
    response_model=TransactionResponse,
    summary="Pay Pending Transaction with Card",
    description="Pay a specific pending transaction using card (saved payment method or new card details)",
    responses={
        200: {
            "description": "Pending payment processed successfully with card",
            "content": {
                "application/json": {
                    "examples": {
                        "SavedCardPayment": {
                            "summary": "Payment with saved card",
                            "value": {
                                "transaction_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                                "transaction_type": "parking_payment",
                                "amount": 2.50,
                                "currency": "AUD",
                                "status": "completed",
                                "description": "Pending parking payment for slot 1A at Westfield Sydney",
                                "created_at": "2025-01-26T19:08:00Z",
                                "completed_at": "2025-01-26T19:15:23Z",
                            },
                        },
                        "NewCardPayment": {
                            "summary": "Payment with new card details",
                            "value": {
                                "transaction_id": "b2c3d4e5-f6g7-8901-bcde-fg2345678901",
                                "transaction_type": "parking_payment",
                                "amount": 5.00,
                                "currency": "AUD",
                                "status": "completed",
                                "description": "Pending parking payment for slot 2B at Shopping Center",
                                "created_at": "2025-01-26T14:30:00Z",
                                "completed_at": "2025-01-26T16:45:12Z",
                            },
                        },
                    }
                }
            },
        },
        400: {
            "description": "Invalid payment method or card details",
            "content": {
                "application/json": {
                    "examples": {
                        "MissingCardDetails": {
                            "summary": "Missing required card details when not using saved payment method",
                            "value": {
                                "detail": "Card details required: card_number, expiry_month, expiry_year, cvv, cardholder_name"
                            },
                        },
                        "InvalidCardNumber": {
                            "summary": "Invalid card number format",
                            "value": {"detail": "Invalid card number format"},
                        },
                        "InvalidExpiryMonth": {
                            "summary": "Invalid expiry month (not 01-12)",
                            "value": {
                                "detail": "Card has expired. Please use a valid card."
                            },
                        },
                        "InvalidCVV": {
                            "summary": "Invalid CVV (not 3-4 digits)",
                            "value": {"detail": "Invalid CVV"},
                        },
                    }
                }
            },
        },
        404: {
            "description": "User not found, transaction not found, or payment method not found",
            "content": {
                "application/json": {
                    "examples": {
                        "UserNotFound": {
                            "summary": "User does not exist",
                            "value": {"detail": "User not found"},
                        },
                        "TransactionNotFound": {
                            "summary": "Pending transaction does not exist",
                            "value": {"detail": "Pending transaction not found"},
                        },
                        "PaymentMethodNotFound": {
                            "summary": "Saved payment method not found or inactive",
                            "value": {"detail": "Payment method not found or inactive"},
                        },
                    }
                }
            },
        },
        422: {
            "description": "Validation error",
            "content": {
                "application/json": {
                    "examples": {
                        "MissingTransactionId": {
                            "summary": "Missing transaction ID",
                            "value": {
                                "detail": [
                                    {
                                        "type": "missing",
                                        "loc": ["query", "transaction_id"],
                                        "msg": "Field required",
                                    }
                                ]
                            },
                        },
                        "InvalidEmail": {
                            "summary": "Invalid email format",
                            "value": {
                                "detail": [
                                    {
                                        "type": "value_error",
                                        "loc": ["query", "email"],
                                        "msg": "value is not a valid email address",
                                        "input": "invalid-email",
                                    }
                                ]
                            },
                        },
                        "InvalidExpiryYear": {
                            "summary": "Invalid expiry year (not integer or out of range)",
                            "value": {
                                "detail": [
                                    {
                                        "type": "int_parsing",
                                        "loc": ["query", "expiry_year"],
                                        "msg": "Input should be a valid integer",
                                        "input": "invalid_year",
                                    }
                                ]
                            },
                        },
                    }
                }
            },
        },
        500: {
            "description": "Internal server error",
            "content": {
                "application/json": {"example": {"detail": "Failed to process payment"}}
            },
        },
    },
)
def pay_pending_transaction_card(
    transaction_id: str = Query(..., description="Pending transaction ID to pay"),
    email: str = Query(..., description="User email address"),
    payment_method_id: Optional[str] = Query(
        None, description="Saved payment method ID (if using saved card)"
    ),
    # New card details (if not using saved card)
    card_number: Optional[str] = Query(
        None, description="Card number (if not using saved card)"
    ),
    expiry_month: Optional[str] = Query(
        None, description="Expiry month MM (if not using saved card)"
    ),
    expiry_year: Optional[int] = Query(
        None, description="Expiry year YYYY (if not using saved card)"
    ),
    cvv: Optional[str] = Query(None, description="CVV (if not using saved card)"),
    cardholder_name: Optional[str] = Query(
        None, description="Cardholder name (if not using saved card)"
    ),
):
    """Pay a specific pending transaction using card"""
    email = email.strip().lower()
    logger.info(
        f"Processing pending payment {transaction_id} with card for user: {email}"
    )

    # Verify user exists
    if not verify_user_exists(email):
        raise HTTPException(status_code=404, detail="User not found")

    # Find the pending transaction
    pending_transaction = transactions_collection.find_one(
        {
            "transaction_id": transaction_id,
            "user_email": email,
            "status": TransactionStatus.PENDING,
        }
    )

    if not pending_transaction:
        raise HTTPException(status_code=404, detail="Pending transaction not found")

    amount = pending_transaction["amount"]

    # Determine payment method
    if payment_method_id:
        # Using saved payment method
        payment_method = payment_methods_collection.find_one(
            {
                "payment_method_id": payment_method_id,
                "user_email": email,
                "is_active": True,
            }
        )

        if not payment_method:
            raise HTTPException(
                status_code=404, detail="Payment method not found or inactive"
            )

        logger.info(
            f"Using saved payment method {payment_method_id} for pending payment"
        )

    else:
        # Using new card details - validate required fields
        if (
            not card_number
            or not card_number.strip()
            or not expiry_month
            or not expiry_month.strip()
            or not expiry_year
            or not cvv
            or not cvv.strip()
            or not cardholder_name
            or not cardholder_name.strip()
        ):
            raise HTTPException(
                status_code=400,
                detail="Card details required: card_number, expiry_month, expiry_year, cvv, cardholder_name",
            )

        # Validate card number format
        card_num = card_number.replace(" ", "").replace("-", "")
        if not card_num.isdigit():
            raise HTTPException(
                status_code=400, detail="Card number must contain only digits"
            )

        # Check overall length bounds first
        card_length = len(card_num)
        if card_length < 13 or card_length > 19:
            raise HTTPException(
                status_code=400, detail="Card number must be between 13-19 digits"
            )

        # Validate CVV format and length
        if not cvv.isdigit():
            raise HTTPException(status_code=400, detail="CVV must be numeric only")
        if len(cvv) < 3 or len(cvv) > 4:
            raise HTTPException(status_code=400, detail="CVV must be 3-4 digits")

        # Use Luhn algorithm for primary validation
        if not is_luhn(card_num):
            raise HTTPException(
                status_code=400,
                detail="Invalid card, please check you have entered the correct details.",
            )

        # Provider-specific length validation based on starting digits
        if card_num.startswith("34") or card_num.startswith("37"):
            # American Express: exactly 15 digits
            if card_length != 15:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid card, please check you have entered the correct details.",
                )
        elif (
            card_num.startswith("30")
            or card_num.startswith("36")
            or card_num.startswith("38")
            or card_num.startswith("39")
        ):
            # Diners Club: 14-16 digits
            if card_length < 14 or card_length > 16:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid card, please check you have entered the correct details.",
                )
        elif card_num.startswith("4"):
            # Visa: can be 13, 16, 18, or 19 digits
            if card_length not in [13, 16, 18, 19]:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid card, please check you have entered the correct details.",
                )
        elif card_num.startswith("5") or card_num.startswith("2"):
            # Mastercard: typically 16 digits
            if card_length != 16:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid card, please check you have entered the correct details.",
                )
        elif card_num.startswith("6"):
            # Discover/UnionPay: typically 16-19 digits
            if card_length < 16 or card_length > 19:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid card, please check you have entered the correct details.",
                )
        else:
            # Other cards: typically 16 digits
            if card_length != 16:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid card, please check you have entered the correct details.",
                )

        # Validate expiry month format and range
        if (
            not expiry_month.isdigit()
            or len(expiry_month) != 2
            or not (1 <= int(expiry_month) <= 12)
        ):
            raise HTTPException(
                status_code=400, detail="Card has expired. Please use a valid card."
            )

        # Validate expiry year range
        if expiry_year < 2025 or expiry_year > 2050:
            raise HTTPException(
                status_code=400, detail="Card has expired. Please use a valid card."
            )

        # Check if card has expired
        current_date = datetime.now()
        current_year = current_date.year
        current_month = current_date.month

        expiry_month_int = int(expiry_month)

        if expiry_year < current_year or (
            expiry_year == current_year and expiry_month_int < current_month
        ):
            next_year = current_year + 1
            raise HTTPException(
                status_code=400, detail=f"Card has expired. Please use a valid card."
            )

        logger.info(
            f"Using new card details for pending payment (ending in {card_num[-4:]})"
        )

    try:
        # simulates successful payment processing
        # Mark transaction as completed
        completed_at = datetime.utcnow()
        transactions_collection.update_one(
            {"transaction_id": transaction_id},
            {
                "$set": {
                    "status": TransactionStatus.COMPLETED,
                    "completed_at": completed_at,
                    "payment_method": "card",
                    "payment_method_id": (
                        payment_method_id if payment_method_id else None
                    ),
                }
            },
        )

        # Record metrics
        metrics.record_revenue(amount, "pending_payment_card")
        metrics.increment_counter("WalletOperations", {"operation": "pay_pending_card"})

        logger.info(
            f"Successfully processed pending payment {transaction_id} with card for user: {email}"
        )

        # Parse created_at properly
        created_at_value = pending_transaction["created_at"]
        if isinstance(created_at_value, str):
            created_at_parsed = datetime.fromisoformat(
                created_at_value.replace("Z", "+00:00")
            )
        else:
            created_at_parsed = created_at_value

        return TransactionResponse(
            transaction_id=transaction_id,
            transaction_type=TransactionType.PARKING_PAYMENT,
            amount=amount,
            currency="AUD",
            status=TransactionStatus.COMPLETED,
            description=pending_transaction["description"],
            created_at=created_at_parsed,
            completed_at=completed_at,
        )

    except Exception as e:
        logger.error(
            f"Failed to process pending payment {transaction_id} with card for user {email}: {str(e)}"
        )
        raise HTTPException(status_code=500, detail="Failed to process payment")
