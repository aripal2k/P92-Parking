from typing import Optional, Dict, Any
from datetime import datetime
import logging
from app.wallet.models import (
    WalletBalance,
    Transaction,
    TransactionType,
    TransactionStatus,
)
from app.database import wallet_collection, transactions_collection, user_collection

logger = logging.getLogger(__name__)


def get_wallet_balance(email: str) -> float:
    """Get the current wallet balance for a user"""
    email = email.strip().lower()

    wallet = wallet_collection.find_one({"user_email": email})
    if wallet:
        return wallet.get("balance", 0.0)
    return 0.0


def has_sufficient_balance(email: str, amount: float) -> bool:
    """Check if user has sufficient balance for a transaction"""
    current_balance = get_wallet_balance(email)
    return current_balance >= amount


def deduct_from_wallet(
    email: str,
    amount: float,
    description: str,
    metadata: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Deduct money from user's wallet for parking payment

    Args:
        email: User email
        amount: Amount to deduct
        description: Transaction description
        metadata: Additional transaction metadata

    Returns:
        Dictionary with transaction details and status
    """
    email = email.strip().lower()

    # Verify user exists
    user = user_collection.find_one({"email": email, "role": "user"})
    if not user:
        return {"success": False, "error": "User not found", "transaction_id": None}

    # Check if user has sufficient balance
    current_balance = get_wallet_balance(email)
    if current_balance < amount:
        return {
            "success": False,
            "error": f"Insufficient balance. Current: ${current_balance:.2f}, Required: ${amount:.2f}",
            "transaction_id": None,
        }

    # Create transaction record
    transaction = Transaction(
        user_email=email,
        transaction_type=TransactionType.PARKING_PAYMENT,
        amount=amount,
        description=description,
        status=TransactionStatus.PENDING,
        metadata=metadata or {},
    )

    try:
        # Insert transaction
        transactions_collection.insert_one(transaction.model_dump())

        # Update wallet balance
        new_balance = current_balance - amount

        wallet_collection.update_one(
            {"user_email": email},
            {"$set": {"balance": new_balance, "last_updated": datetime.utcnow()}},
            upsert=True,
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

        logger.info(f"Successfully deducted ${amount} from wallet for user: {email}")

        return {
            "success": True,
            "transaction_id": transaction.transaction_id,
            "new_balance": new_balance,
            "amount_deducted": amount,
        }

    except Exception as e:
        logger.error(f"Failed to deduct from wallet for user {email}: {str(e)}")

        # Mark transaction as failed if it was created
        transactions_collection.update_one(
            {"transaction_id": transaction.transaction_id},
            {"$set": {"status": TransactionStatus.FAILED}},
        )

        return {
            "success": False,
            "error": "Failed to process payment",
            "transaction_id": transaction.transaction_id,
        }


def refund_to_wallet(
    email: str,
    amount: float,
    description: str,
    original_transaction_id: Optional[str] = None,
    metadata: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Refund money to user's wallet

    Args:
        email: User email
        amount: Amount to refund
        description: Refund description
        original_transaction_id: Original transaction ID being refunded
        metadata: Additional transaction metadata

    Returns:
        Dictionary with refund transaction details
    """
    email = email.strip().lower()

    # Verify user exists
    user = user_collection.find_one({"email": email, "role": "user"})
    if not user:
        return {"success": False, "error": "User not found", "transaction_id": None}

    # Create refund transaction
    refund_metadata = metadata or {}
    if original_transaction_id:
        refund_metadata["original_transaction_id"] = original_transaction_id

    transaction = Transaction(
        user_email=email,
        transaction_type=TransactionType.REFUND,
        amount=amount,
        description=description,
        status=TransactionStatus.PENDING,
        metadata=refund_metadata,
    )

    try:
        # Insert transaction
        transactions_collection.insert_one(transaction.model_dump())

        # Update wallet balance
        current_balance = get_wallet_balance(email)
        new_balance = current_balance + amount

        wallet_collection.update_one(
            {"user_email": email},
            {"$set": {"balance": new_balance, "last_updated": datetime.utcnow()}},
            upsert=True,
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

        logger.info(f"Successfully refunded ${amount} to wallet for user: {email}")

        return {
            "success": True,
            "transaction_id": transaction.transaction_id,
            "new_balance": new_balance,
            "amount_refunded": amount,
        }

    except Exception as e:
        logger.error(f"Failed to refund to wallet for user {email}: {str(e)}")

        # Mark transaction as failed if it was created
        transactions_collection.update_one(
            {"transaction_id": transaction.transaction_id},
            {"$set": {"status": TransactionStatus.FAILED}},
        )

        return {
            "success": False,
            "error": "Failed to process refund",
            "transaction_id": transaction.transaction_id,
        }


def create_wallet_if_not_exists(email: str) -> WalletBalance:
    """Create a wallet for a user if it doesn't exist"""
    email = email.strip().lower()

    wallet = wallet_collection.find_one({"user_email": email})
    if wallet:
        return WalletBalance(**wallet)

    # Create new wallet
    new_wallet = WalletBalance(user_email=email, balance=0.0)
    wallet_collection.insert_one(new_wallet.model_dump())
    logger.info(f"Created new wallet for user: {email}")
    return new_wallet
