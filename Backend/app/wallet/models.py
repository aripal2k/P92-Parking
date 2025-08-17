from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum
import uuid
from luhncheck import is_luhn


class PaymentMethodType(str, Enum):
    CREDIT_CARD = "credit_card"
    DEBIT_CARD = "debit_card"
    BANK_ACCOUNT = "bank_account"
    DIGITAL_WALLET = "digital_wallet"


class TransactionType(str, Enum):
    ADD_MONEY = "add_money"
    PARKING_PAYMENT = "parking_payment"
    REFUND = "refund"
    TRANSFER = "transfer"


class TransactionStatus(str, Enum):
    PENDING = "pending"  # transaction is being processed
    COMPLETED = "completed"
    FAILED = (
        "failed"  # transaction failed due to insufficient funds, invalid card, etc.
    )
    CANCELLED = "cancelled"  # user manually cancelled the transaction


class PaymentMethod(BaseModel):
    payment_method_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_email: EmailStr
    method_type: PaymentMethodType
    username: str  # e.g., "Visa ending in 1234"
    cardholder_name: str = Field(
        min_length=1, max_length=100, description="Name on the card"
    )
    last_four_digits: str = Field(min_length=4, max_length=4)
    expiry_month: Optional[str] = Field(
        None, pattern=r"^(0[1-9]|1[0-2])$", description="2-digit month (01-12)"
    )
    expiry_year: Optional[int] = Field(None, ge=2025, le=2050)
    is_default: bool = False
    is_active: bool = True
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    @field_validator("last_four_digits")
    @classmethod
    def validate_last_four(cls, v):
        if not v.isdigit():
            raise ValueError("Last four digits must be numeric")
        return v

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}


class WalletBalance(BaseModel):
    user_email: EmailStr
    balance: float = Field(0.0, ge=0.0)
    currency: str = "AUD"
    last_updated: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}


class Transaction(BaseModel):
    transaction_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_email: EmailStr
    transaction_type: TransactionType
    amount: float = Field(gt=0.0)
    currency: str = "AUD"
    status: TransactionStatus = TransactionStatus.PENDING
    payment_method_id: Optional[str] = None
    description: str
    metadata: Optional[Dict[str, Any]] = {}
    created_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}


# Request models for API endpoints
class AddMoneyRequest(BaseModel):
    email: EmailStr
    amount: float = Field(
        gt=0.0, le=1000.0, description="Amount to add (max $1000 per transaction)"
    )
    payment_method_id: str


class CreatePaymentMethodRequest(BaseModel):
    email: EmailStr
    method_type: PaymentMethodType
    username: str = Field(min_length=1, max_length=100)
    card_number: str = Field(
        description="Full card number (13-19 digits, will be encrypted)"
    )
    expiry_month: Optional[str] = Field(
        None, pattern=r"^(0[1-9]|1[0-2])$", description="2-digit month (01-12)"
    )
    expiry_year: Optional[int] = Field(None)
    cvv: str = Field(description="CVV code (will not be stored)")
    cardholder_name: Optional[str] = None
    is_default: bool = False

    @field_validator("card_number")
    @classmethod
    def validate_card_number(cls, v):
        # Remove spaces and validate
        card_num = v.replace(" ", "").replace("-", "")
        if not card_num.isdigit():
            raise ValueError("Card number must contain only digits")

        # Check overall length bounds first
        card_length = len(card_num)
        if card_length < 13 or card_length > 19:
            raise ValueError("Card number must be between 13-19 digits")

        # Use Luhn algorithm for primary checksum validation
        if not is_luhn(card_num):
            raise ValueError(
                "Invalid card, please check you have entered the correct details."
            )

        # Provider-specific length validation based on starting digits
        if card_num.startswith("34") or card_num.startswith("37"):
            # American Express: exactly 15 digits
            if card_length != 15:
                raise ValueError(
                    "Invalid card, please check you have entered the correct details."
                )
        elif (
            card_num.startswith("30")
            or card_num.startswith("36")
            or card_num.startswith("38")
            or card_num.startswith("39")
        ):
            # Diners Club: 14-16 digits
            if card_length < 14 or card_length > 16:
                raise ValueError(
                    "Invalid card, please check you have entered the correct details."
                )
        elif card_num.startswith("4"):
            # Visa: can be 13, 16, 18, or 19 digits
            if card_length not in [13, 16, 18, 19]:
                raise ValueError(
                    "Invalid card, please check you have entered the correct details."
                )
        elif card_num.startswith("5") or card_num.startswith("2"):
            # Mastercard: typically 16 digits
            if card_length != 16:
                raise ValueError(
                    "Invalid card, please check you have entered the correct details."
                )
        elif card_num.startswith("6"):
            # Discover/UnionPay: typically 16-19 digits
            if card_length < 16 or card_length > 19:
                raise ValueError(
                    "Invalid card, please check you have entered the correct details."
                )
        else:
            # Other cards: typically 16 digits
            if card_length != 16:
                raise ValueError(
                    "Invalid card, please check you have entered the correct details."
                )

        return card_num

    @model_validator(mode="after")
    def validate_card_fields(self):
        # Check for empty or missing required fields
        if (
            not self.card_number
            or not self.card_number.strip()
            or not self.expiry_month
            or not self.expiry_month.strip()
            or not self.expiry_year
            or not self.cvv
            or not self.cvv.strip()
            or not self.cardholder_name
            or not self.cardholder_name.strip()
        ):
            raise ValueError(
                "Card details required: card_number, expiry_month, expiry_year, cvv, cardholder_name"
            )

        # Validate basic field formats
        if not self.cvv.isdigit():
            raise ValueError("CVV must be numeric only")
        if len(self.cvv) < 3 or len(self.cvv) > 4:
            raise ValueError("CVV must be 3-4 digits")

        if (
            not self.expiry_month.isdigit()
            or len(self.expiry_month) != 2
            or not (1 <= int(self.expiry_month) <= 12)
        ):
            raise ValueError("Card has expired. Please use a valid card.")

        if self.expiry_year < 2025 or self.expiry_year > 2050:
            raise ValueError("Card has expired. Please use a valid card.")

        # Check if card has already expired
        if self.expiry_month and self.expiry_year:
            current_date = datetime.now()
            current_year = current_date.year
            current_month = current_date.month

            expiry_month_int = int(self.expiry_month)

            if self.expiry_year < current_year or (
                self.expiry_year == current_year and expiry_month_int < current_month
            ):
                next_year = current_year + 1
                raise ValueError(f"Card has expired. Please use a valid card.")
        return self


class UpdatePaymentMethodRequest(BaseModel):
    email: EmailStr
    payment_method_id: str
    expiry_month: Optional[str] = Field(
        None, pattern=r"^(0[1-9]|1[0-2])$", description="2-digit month (01-12)"
    )
    expiry_year: Optional[int] = Field(None)
    is_default: Optional[bool] = None
    is_active: Optional[bool] = None

    @model_validator(mode="after")
    def validate_expiry_fields(self):
        # Only validate if both fields are provided
        if self.expiry_month is not None and self.expiry_year is not None:
            if (
                not self.expiry_month.isdigit()
                or len(self.expiry_month) != 2
                or not (1 <= int(self.expiry_month) <= 12)
            ):
                raise ValueError("Card has expired. Please use a valid card.")

            if self.expiry_year < 2025 or self.expiry_year > 2050:
                raise ValueError("Card has expired. Please use a valid card.")

            # Check if card has already expired
            current_date = datetime.now()
            current_year = current_date.year
            current_month = current_date.month

            expiry_month_int = int(self.expiry_month)

            if self.expiry_year < current_year or (
                self.expiry_year == current_year and expiry_month_int < current_month
            ):
                raise ValueError(f"Card has expired. Please use a valid card.")

        return self


class WalletBalanceResponse(BaseModel):
    balance: float
    currency: str
    last_updated: datetime

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}


class TransactionResponse(BaseModel):
    transaction_id: str
    transaction_type: TransactionType
    amount: float
    currency: str
    status: TransactionStatus
    description: str
    created_at: datetime
    completed_at: Optional[datetime] = None

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}
