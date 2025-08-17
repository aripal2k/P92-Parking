from fastapi import APIRouter, HTTPException, Request, status
from app.auth.auth import (
    UserCreate,
    OTPVerificationRequest,
    UserLogin,
    ChangePasswordRequest,
    ResetOTPVerificationRequest,
    ResetPasswordRequest,
    ForgotPasswordRequest,
    DeleteAccountRequest,
    AdminCreate,
    UserEdit,
)
from typing import Optional
from app.auth.utils import hash_password, verify_password
from app.database import (
    user_collection,
    wallet_collection,
    payment_methods_collection,
    transactions_collection,
    session_collection,
    emissions_collection,
)
import traceback
import time
import random
import string
import smtplib
from email.message import EmailMessage
import re
from bson import ObjectId
import logging
from app.cloudwatch_metrics import metrics

router = APIRouter(prefix="/auth", tags=["auth"])


def generate_otp(length=6):
    return "".join(random.choices(string.digits, k=length))


@router.post(
    "/register-request",
    responses={
        200: {
            "description": "OTP sent to email. Please verify to complete registration.",
            "content": {
                "application/json": {
                    "example": {
                        "msg": "OTP sent to email. Please verify to complete registration."
                    }
                }
            },
        },
        400: {
            "description": "Bad request (email/username taken, password mismatch, etc.)",
            "content": {
                "application/json": {
                    "examples": {
                        "EmailRegistered": {
                            "summary": "Email already registered",
                            "value": {"detail": "Email already registered"},
                        },
                        "EmptyUsername": {
                            "summary": "Empty username",
                            "value": {"detail": "Username cannot be empty"},
                        },
                        "EmptyFullName": {
                            "summary": "Empty fullname",
                            "value": {"detail": "Full name cannot be empty"},
                        },
                        "UsernameTaken": {
                            "summary": "Username already taken",
                            "value": {"detail": "Username already taken"},
                        },
                        "PasswordMismatch": {
                            "summary": "Passwords do not match",
                            "value": {"detail": "Passwords do not match"},
                        },
                        "PasswordTooShort": {
                            "summary": "Password too short",
                            "value": {
                                "detail": "Password must be at least 8 characters long"
                            },
                        },
                        "PasswordNoNumber": {
                            "summary": "Missing number",
                            "value": {
                                "detail": "Password must contain at least one number"
                            },
                        },
                        "PasswordNoSpecial": {
                            "summary": "Missing special character",
                            "value": {
                                "detail": "Password must contain at least one special character"
                            },
                        },
                        "PasswordTooCommon": {
                            "summary": "Too common",
                            "value": {
                                "detail": "Password is too common. Please choose a more secure one."
                            },
                        },
                    }
                }
            },
        },
        500: {
            "description": "Internal Server Error",
            "content": {
                "application/json": {"example": {"detail": "Internal Server Error"}}
            },
        },
    },
)
def register_request(user: UserCreate):
    logging.info(f"[REGISTRATION REQUEST] Requesting OTP for: {user.email}")
    try:
        if not user.username.strip():
            raise HTTPException(status_code=400, detail="Username cannot be empty")
        if not user.fullname.strip():
            raise HTTPException(status_code=400, detail="Full name cannot be empty")
        if len(user.password) < 8:
            raise HTTPException(
                status_code=400, detail="Password must be at least 8 characters long"
            )
        if not re.search(r"\d", user.password):
            raise HTTPException(
                status_code=400, detail="Password must contain at least one number"
            )
        if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", user.password):
            raise HTTPException(
                status_code=400,
                detail="Password must contain at least one special character",
            )
        if user.password != user.confirm_password:
            raise HTTPException(status_code=400, detail="Passwords do not match")

        COMMON_PASSWORDS = {"123456", "123456789", "qwerty", "password", "12345678"}
        for common in COMMON_PASSWORDS:
            if common in user.password.lower():
                raise HTTPException(
                    status_code=400,
                    detail="Password is too common. Please choose a more secure one.",
                )

        user.email = user.email.strip().lower()
        if user_collection.find_one({"email": user.email}):
            raise HTTPException(status_code=400, detail="Email already registered")
        if user_collection.find_one({"username": user.username}):
            raise HTTPException(status_code=400, detail="Username already taken")

        # Generate OTP and store it with expiry time
        otp = generate_otp()
        expire_time = time.time() + 10 * 60

        # Temporarily store registration info (replace with Redis/secure store in production)
        user_collection.update_one(
            {"email": user.email},
            {
                "$set": {
                    "temp_user": {
                        "email": user.email,
                        "username": user.username,
                        "fullname": user.fullname,
                        "password": hash_password(user.password),
                        "vehicle": None,
                        "license_plate": None,  # added for license plate (for Edit Profile)
                        "phone_number": None,  # added for phone number (for Edit Profile)
                        "address": None,  # added for address (for Edit Profile)
                        "failed_login_attempts": 0,  # added for login failure count (this is helpful to check brute force login times)
                        "suspend_until": 0,  # added for login failure count (this is helpful to check brute force login times)
                        "role": "user",
                        "current_session_id": None,  # added for parking session management
                        "subscription_plan": "basic",  # default subscription plan
                    },
                    "otp": otp,
                    "otp_expire": expire_time,
                }
            },
            upsert=True,
        )

        send_email_otp(user.email, otp)
        metrics.record_auth_event(event_type="register-request", success=True)
        logging.info(f"Registration OTP sent to {user.email}")
        return {"msg": "OTP sent to email. Please verify to complete registration."}
    except HTTPException as e:
        logging.warning(f"Registration failed for {user.email} - {e.detail}")
        metrics.record_auth_event(event_type="register-request", success=False)
        raise
    except Exception as e:
        logging.error(f"Unexpected error during registration for {user.email}: {e}")
        metrics.record_auth_event(event_type="register-request", success=False)
        raise HTTPException(status_code=500, detail="Internal Server Error")


@router.post(
    "/verify-registration",
    responses={
        200: {
            "description": "User registered successfully after OTP verification.",
            "content": {
                "application/json": {"example": {"msg": "Registration successful!"}}
            },
        },
        400: {
            "description": "Bad request (OTP issues, expired or missing registration data).",
            "content": {
                "application/json": {
                    "examples": {
                        "MissingOTP": {
                            "summary": "No OTP requested or expired",
                            "value": {"detail": "No OTP requested or OTP expired."},
                        },
                        "ExpiredOTP": {
                            "summary": "OTP code has expired",
                            "value": {"detail": "OTP code has expired."},
                        },
                        "IncorrectOTP": {
                            "summary": "Incorrect OTP",
                            "value": {"detail": "OTP code is incorrect."},
                        },
                        "NoTempUser": {
                            "summary": "No pending registration found",
                            "value": {"detail": "No pending registration found."},
                        },
                    }
                }
            },
        },
        404: {
            "description": "User not found.",
            "content": {"application/json": {"example": {"detail": "User not found"}}},
        },
        500: {
            "description": "Internal Server Error",
            "content": {
                "application/json": {"example": {"detail": "Internal Server Error"}}
            },
        },
    },
)
def verify_registration(data: OTPVerificationRequest):
    logging.info(f"[VERIFY REGISTRATION] Verifying OTP for: {data.email}")
    try:
        data.email = data.email.strip().lower()
        user_doc = user_collection.find_one({"email": data.email})
        if not user_doc:
            raise HTTPException(status_code=404, detail="User not found")

        if "otp" not in user_doc or "otp_expire" not in user_doc:
            raise HTTPException(
                status_code=400, detail="No OTP requested or OTP expired."
            )

        if user_doc["otp_expire"] < time.time():
            raise HTTPException(status_code=400, detail="OTP code has expired.")

        if user_doc["otp"] != data.otp:
            raise HTTPException(status_code=400, detail="OTP code is incorrect.")

        temp_user = user_doc.get("temp_user")
        if not temp_user:
            raise HTTPException(
                status_code=400, detail="No pending registration found."
            )

        # preserve original _id
        user_id = user_doc.get("_id", ObjectId())

        # fix the document in a preferred order
        ordered_doc = {
            "_id": user_id,
            "email": temp_user["email"],
            "username": temp_user["username"],
            "fullname": temp_user["fullname"],
            "password": temp_user["password"],
            "vehicle": temp_user["vehicle"],
            "license_plate": temp_user["license_plate"],
            "phone_number": temp_user["phone_number"],
            "address": temp_user["address"],
            "failed_login_attempts": temp_user["failed_login_attempts"],
            "suspend_until": temp_user["suspend_until"],
            "role": temp_user["role"],
            "current_session_id": None,
            "subscription_plan": temp_user.get(
                "subscription_plan", "basic"
            ),  # default to basic
        }

        # Replace the document w the ordered one
        user_collection.replace_one({"email": data.email}, ordered_doc)

        logging.info(f"[VERIFY REGISTRATION] Registration complete for: {data.email}")
        metrics.record_auth_event(event_type="verify-registration", success=True)

        return {"msg": "Registration successful!"}

    except HTTPException as e:
        logging.warning(f"[VERIFY REGISTRATION] Failed for: {data.email} - {e.detail}")
        metrics.record_auth_event(event_type="verify-registration", success=False)
        raise e

    except Exception as e:
        logging.error(
            f"[VERIFY REGISTRATION] Unexpected error for: {data.email} - {str(e)}"
        )
        metrics.record_auth_event(event_type="verify-registration", success=False)
        raise HTTPException(status_code=500, detail="Internal Server Error")


# used to print list of successfully registered user details (excl password)
# accessed through: http://localhost:8000/auth/users


@router.get("/users")
def get_users():
    query = {"role": "user"}
    users = list(user_collection.find(query, {"_id": 0, "password": 0}))
    return users


@router.post(
    "/login",
    responses={
        200: {
            "description": "Login success",
            "content": {"application/json": {"example": {"msg": "Login success"}}},
        },
        401: {
            "description": "Unauthorized (email not registered or password/email incorrect)",
            "content": {
                "application/json": {
                    "examples": {
                        "EmailNotRegistered": {
                            "summary": "Email not registered",
                            "value": {"detail": "Email is not registered."},
                        },
                        "PasswordOrEmailIncorrect": {
                            "summary": "Password or email is incorrect",
                            "value": {"detail": "Password or email is incorrect."},
                        },
                    }
                }
            },
        },
        403: {
            "description": "Account suspended",
            "content": {
                "application/json": {
                    "example": {
                        "detail": "Account is suspended, please try again in 30 minutes."
                    }
                }
            },
        },
    },
)
def login(user: UserLogin, request: Request):
    user.email = user.email.strip().lower()
    email = user.email
    logging.info(f"[LOGIN] Login attempt for: {email}")
    db_user = user_collection.find_one({"email": email})

    # Edge case 1: check if email is registered
    if not db_user:
        logging.warning(f"Login attempt with unregistered email: {email}")
        metrics.record_auth_event("login", False)
        raise HTTPException(status_code=401, detail="Email is not registered.")

    # Edge case 2: login failed 5 times, account is suspended for 30 minutes
    if db_user.get("suspend_until", 0) > time.time():
        logging.warning(f"Login attempt on suspended account: {email}")
        metrics.record_auth_event("login_suspended", False)
        raise HTTPException(
            status_code=403,
            detail="Account is suspended, please try again in 30 minutes.",
        )

    if not verify_password(user.password, db_user["password"]):
        failed_attempts = db_user.get("failed_login_attempts", 0) + 1
        logging.warning(f"Failed login attempt {failed_attempts} for: {email}")
        update = {"$set": {"failed_login_attempts": failed_attempts}}
        if failed_attempts >= 5:
            update["$set"]["suspend_until"] = time.time() + 2 * 60
            update["$set"]["failed_login_attempts"] = 0
            user_collection.update_one({"email": email}, update)
            logging.warning(
                f"Account suspended due to too many failed attempts: {email}"
            )
            metrics.record_auth_event("login_suspended", False)
            raise HTTPException(
                status_code=403,
                detail="Account is suspended, please try again in 30 minutes.",
            )
        user_collection.update_one({"email": email}, update)
        metrics.record_auth_event("login", False)
        raise HTTPException(status_code=401, detail="Password or email is incorrect.")

    # login success, reset count
    user_collection.update_one(
        {"email": email}, {"$set": {"failed_login_attempts": 0, "suspend_until": 0}}
    )
    logging.info(f"Successful login for: {email}")
    metrics.record_auth_event("login", True)
    return {"msg": "Login success"}


# sends otp code to provided user email from our noreply acct
def send_email_otp(to_email: str, otp_code: str):
    EMAIL_ADDRESS = "noreply.autospotparking@gmail.com"
    EMAIL_PASSWORD = "gjntkbwxxwjyxbiu"

    msg = EmailMessage()
    msg["Subject"] = "Your One-Time Password (OTP) Code"
    msg["From"] = EMAIL_ADDRESS
    msg["To"] = to_email
    msg.set_content(f"Your OTP code is: {otp_code}")

    # customised OTP message - changes the font & structure of message
    html_content = f"""
    <html>
      <body>
        <p>Your OTP code is:</p>
        <h2 style="font-size: 24px; color: #2a2a2a;">{otp_code}</h2>
        <p>This code will expire in 10 minutes.</p>
      </body>
    </html>
    """
    msg.add_alternative(html_content, subtype="html")

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
            smtp.login(EMAIL_ADDRESS, EMAIL_PASSWORD)
            smtp.send_message(msg)
    except Exception as e:
        print("Failed to send OTP email:", e)


@router.post(
    "/change-password",
    responses={
        200: {
            "description": "Password changed successfully",
            "content": {
                "application/json": {
                    "example": {"msg": "Password changed successfully."}
                }
            },
        },
        401: {
            "description": "Current password is incorrect",
            "content": {
                "application/json": {
                    "example": {"detail": "Current password is incorrect."}
                }
            },
        },
        404: {
            "description": "User not found",
            "content": {"application/json": {"example": {"detail": "User not found."}}},
        },
        400: {
            "description": "Bad request (password mismatch or weak password)",
            "content": {
                "application/json": {
                    "examples": {
                        "PasswordMismatch": {
                            "summary": "New password and confirmation do not match",
                            "value": {
                                "detail": "New password and confirmation do not match."
                            },
                        },
                        "PasswordTooShort": {
                            "summary": "Too short",
                            "value": {
                                "detail": "Password must be at least 8 characters long"
                            },
                        },
                        "PasswordNoNumber": {
                            "summary": "Missing number",
                            "value": {
                                "detail": "Password must contain at least one number"
                            },
                        },
                        "PasswordNoSpecial": {
                            "summary": "Missing special character",
                            "value": {
                                "detail": "Password must contain at least one special character"
                            },
                        },
                        "PasswordTooCommon": {
                            "summary": "Too common",
                            "value": {
                                "detail": "Password is too common. Please choose a more secure one."
                            },
                        },
                        "PasswordSameAsCurrent": {
                            "summary": "Same as current",
                            "value": {
                                "detail": "New password cannot be the same as the current password."
                            },
                        },
                    }
                }
            },
        },
    },
)
def change_password(data: ChangePasswordRequest):
    data.email = data.email.strip().lower()
    db_user = user_collection.find_one({"email": data.email})
    if not db_user:
        # Edge case 1: check if user is registered
        raise HTTPException(status_code=404, detail="User not found.")

    # Edge case 2: check if current password is correct
    if not verify_password(data.current_password, db_user["password"]):
        raise HTTPException(status_code=401, detail="Current password is incorrect.")

    # Edge case 3: check if new password and confirmation do not match
    if data.new_password != data.confirm_new_password:
        raise HTTPException(
            status_code=400, detail="New password and confirmation do not match."
        )

    # Edge case 4: new password and current password cannot be the same
    if data.new_password == data.current_password:
        raise HTTPException(
            status_code=400,
            detail="New password cannot be the same as the current password.",
        )

    # Edge case 5: check if new password is strong enough
    if len(data.new_password) < 8:
        raise HTTPException(
            status_code=400, detail="Password must be at least 8 characters long"
        )

    if not any(c.isdigit() for c in data.new_password):
        raise HTTPException(
            status_code=400, detail="Password must contain at least one number"
        )

    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", data.new_password):
        raise HTTPException(
            status_code=400,
            detail="Password must contain at least one special character",
        )

    COMMON_PASSWORDS = {"123456", "123456789", "qwerty", "password", "12345678"}
    for common in COMMON_PASSWORDS:
        if common in data.new_password.lower():
            raise HTTPException(
                status_code=400,
                detail="Password is too common. Please choose a more secure one.",
            )

    # update password
    hashed_pw = hash_password(data.new_password)
    user_collection.update_one({"email": data.email}, {"$set": {"password": hashed_pw}})

    # update success
    return {"msg": "Password changed successfully."}


@router.post(
    "/forgot-password",
    responses={
        200: {
            "description": "OTP code sent to your email.",
            "content": {
                "application/json": {"example": {"msg": "OTP code sent to your email."}}
            },
        },
        404: {
            "description": "User not found",
            "content": {"application/json": {"example": {"detail": "User not found."}}},
        },
    },
)
def forgot_password(data: ForgotPasswordRequest):
    data.email = data.email.strip().lower()
    db_user = user_collection.find_one({"email": data.email})
    if not db_user:
        # Edge case 1: check if user is registered
        raise HTTPException(status_code=404, detail="User not found.")
    otp = generate_otp()
    expire_time = time.time() + 10 * 60
    user_collection.update_one(
        {"email": data.email},
        {"$set": {"reset_otp": otp, "reset_otp_expire": expire_time}},
    )
    # successfully sends OTP to the user email provided
    send_email_otp(data.email, otp)
    return {"msg": "OTP code sent to your email."}


@router.post(
    "/verify-reset-otp",
    responses={
        200: {
            "description": "OTP verified successfully.",
            "content": {
                "application/json": {"example": {"msg": "OTP verified successfully."}}
            },
        },
        400: {
            "description": "Bad request (missing or expired OTP).",
            "content": {
                "application/json": {
                    "examples": {
                        "No OTP": {
                            "summary": "No OTP or expired",
                            "value": {"detail": "No OTP requested or OTP expired."},
                        },
                        "Expired": {
                            "summary": "OTP expired",
                            "value": {"detail": "OTP code has expired."},
                        },
                        "Incorrect": {
                            "summary": "Wrong OTP",
                            "value": {"detail": "OTP code is incorrect."},
                        },
                    }
                }
            },
        },
        404: {
            "description": "User not found.",
            "content": {"application/json": {"example": {"detail": "User not found."}}},
        },
    },
)
def verify_reset_otp(data: ResetOTPVerificationRequest):
    data.email = data.email.strip().lower()
    db_user = user_collection.find_one({"email": data.email})
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found.")

    if "reset_otp" not in db_user or "reset_otp_expire" not in db_user:
        raise HTTPException(status_code=400, detail="No OTP requested or OTP expired.")

    if db_user["reset_otp_expire"] < time.time():
        raise HTTPException(status_code=400, detail="OTP code has expired.")

    if db_user["reset_otp"] != data.otp:
        raise HTTPException(status_code=400, detail="OTP code is incorrect.")

    # otherwise mark OTP as verified
    user_collection.update_one(
        {"email": data.email}, {"$set": {"reset_verified": True}}
    )

    return {"msg": "OTP verified successfully."}


@router.post(
    "/reset-password",
    responses={
        200: {
            "description": "Password has been reset successfully.",
            "content": {
                "application/json": {
                    "example": {"msg": "Password has been reset successfully."}
                }
            },
        },
        404: {
            "description": "User not found",
            "content": {"application/json": {"example": {"detail": "User not found."}}},
        },
        400: {
            "description": "Bad request (OTP not verified or password validation failed)",
            "content": {
                "application/json": {
                    "examples": {
                        "OTPNotVerified": {
                            "summary": "OTP not verified",
                            "value": {
                                "detail": "OTP verification required before resetting password."
                            },
                        },
                        "PasswordMismatch": {
                            "summary": "New password and confirmation do not match",
                            "value": {
                                "detail": "New password and confirmation do not match."
                            },
                        },
                        "PasswordTooShort": {
                            "summary": "Password too short",
                            "value": {
                                "detail": "Password must be at least 8 characters long"
                            },
                        },
                        "PasswordNoNumber": {
                            "summary": "Missing number",
                            "value": {
                                "detail": "Password must contain at least one number"
                            },
                        },
                        "PasswordNoSpecial": {
                            "summary": "Missing special character",
                            "value": {
                                "detail": "Password must contain at least one special character"
                            },
                        },
                        "PasswordTooCommon": {
                            "summary": "Too common",
                            "value": {
                                "detail": "Password is too common. Please choose a more secure one."
                            },
                        },
                        "PasswordSameAsCurrent": {
                            "summary": "Same as current password",
                            "value": {
                                "detail": "New password cannot be the same as the current password."
                            },
                        },
                    }
                }
            },
        },
    },
)
def reset_password(data: ResetPasswordRequest):
    data.email = data.email.strip().lower()
    db_user = user_collection.find_one({"email": data.email})
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found.")

    # Ensure OTP has been verified first
    if not db_user.get("reset_verified"):
        raise HTTPException(
            status_code=400,
            detail="OTP verification required before resetting password.",
        )

    # Check if new password and confirmation match
    if data.new_password != data.confirm_new_password:
        raise HTTPException(
            status_code=400, detail="New password and confirmation do not match."
        )

    # Password strength checks
    if len(data.new_password) < 8:
        raise HTTPException(
            status_code=400, detail="Password must be at least 8 characters long"
        )
    if not re.search(r"\d", data.new_password):
        raise HTTPException(
            status_code=400, detail="Password must contain at least one number"
        )
    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", data.new_password):
        raise HTTPException(
            status_code=400,
            detail="Password must contain at least one special character",
        )

    COMMON_PASSWORDS = {"123456", "123456789", "qwerty", "password", "12345678"}
    for common in COMMON_PASSWORDS:
        if common in data.new_password.lower():
            raise HTTPException(
                status_code=400,
                detail="Password is too common. Please choose a more secure one.",
            )

    if verify_password(data.new_password, db_user["password"]):
        raise HTTPException(
            status_code=400,
            detail="New password cannot be the same as the current password.",
        )

    # Save new password and clear the OTP fields (clean up)
    hashed_pw = hash_password(data.new_password)
    user_collection.update_one(
        {"email": data.email},
        {
            "$set": {"password": hashed_pw},
            "$unset": {"reset_otp": "", "reset_otp_expire": "", "reset_verified": ""},
        },
    )

    return {"msg": "Password has been reset successfully."}


@router.delete(
    "/delete-account",
    responses={
        200: {
            "description": "Account deleted successfully.",
            "content": {
                "application/json": {
                    "example": {"msg": "Account deleted successfully."}
                }
            },
        },
        404: {
            "description": "User not found",
            "content": {"application/json": {"example": {"detail": "User not found."}}},
        },
        401: {
            "description": "Password is incorrect",
            "content": {
                "application/json": {"example": {"detail": "Password is incorrect."}}
            },
        },
    },
)
def delete_account(data: DeleteAccountRequest):
    data.email = data.email.strip().lower()
    db_user = user_collection.find_one({"email": data.email})
    if not db_user:
        # Edge case 1: check if user is registered
        raise HTTPException(status_code=404, detail="User not found.")

    # Edge case 2: check if password is correct
    if not verify_password(data.password, db_user["password"]):
        raise HTTPException(status_code=401, detail="Password is incorrect.")

    # Delete all user-related data comprehensively
    user_email = data.email

    try:
        # Delete wallet data
        wallet_delete_result = wallet_collection.delete_many({"user_email": user_email})
        print(
            f"Deleted {wallet_delete_result.deleted_count} wallet records for {user_email}"
        )

        # Delete payment methods
        payment_methods_delete_result = payment_methods_collection.delete_many(
            {"user_email": user_email}
        )
        print(
            f"Deleted {payment_methods_delete_result.deleted_count} payment methods for {user_email}"
        )

        # Delete transaction history
        transactions_delete_result = transactions_collection.delete_many(
            {"user_email": user_email}
        )
        print(
            f"Deleted {transactions_delete_result.deleted_count} transactions for {user_email}"
        )

        # Delete parking sessions
        sessions_delete_result = session_collection.delete_many(
            {"user_email": user_email}
        )
        print(
            f"Deleted {sessions_delete_result.deleted_count} parking sessions for {user_email}"
        )

        # Delete emissions data (use username field)
        username = db_user.get("username")
        if username:
            emissions_delete_result = emissions_collection.delete_many(
                {"username": username}
            )
            print(
                f"Deleted {emissions_delete_result.deleted_count} emissions records for {username}"
            )
        else:
            print(
                f"No username found for {user_email}, skipping emission records deletion"
            )

        # Finally, delete the user account itself
        user_delete_result = user_collection.delete_one({"email": user_email})
        print(f"Deleted user account for {user_email}")

        print(f"✅ Successfully deleted all data for user: {user_email}")

    except Exception as e:
        print(f"❌ Error during account deletion for {user_email}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Failed to delete account completely. Please try again.",
        )

    return {"msg": "Account deleted successfully."}


@router.put(
    "/edit-profile",
    responses={
        200: {
            "description": "Profile updated successfully.",
            "content": {
                "application/json": {
                    "example": {"msg": "Profile updated successfully."}
                }
            },
        },
        400: {
            "description": "Bad request (no fields to update or username taken)",
            "content": {
                "application/json": {
                    "examples": {
                        "NoFields": {
                            "summary": "No fields to update",
                            "value": {"detail": "No fields to update."},
                        },
                        "UsernameTaken": {
                            "summary": "Username already taken",
                            "value": {"detail": "Username already taken."},
                        },
                        "EmptyFullName": {
                            "summary": "Full name cannot be empty",
                            "value": {"detail": "Full name cannot be empty."},
                        },
                        "EmptyUsername": {
                            "summary": "Username cannot be empty",
                            "value": {"detail": "Username cannot be empty."},
                        },
                        "EmptyLicensePlate": {
                            "summary": "License plate cannot be empty",
                            "value": {"detail": "License plate cannot be empty."},
                        },
                    }
                }
            },
        },
        404: {
            "description": "User not found",
            "content": {"application/json": {"example": {"detail": "User not found."}}},
        },
    },
)
def edit_profile(data: UserEdit):
    data.email = data.email.strip().lower()
    db_user = user_collection.find_one({"email": data.email})
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found.")
    update_fields = {}
    if data.fullname is not None:
        # Fullname cannot be empty
        if data.fullname.strip() == "":
            raise HTTPException(status_code=400, detail="Full name cannot be empty.")
        update_fields["fullname"] = data.fullname.strip()

    if data.username is not None:
        # Username cannot be empty - check if it is taken
        if data.username.strip() == "":
            raise HTTPException(status_code=400, detail="Username cannot be empty.")
        username_value = data.username.strip()
        if user_collection.find_one(
            {"username": username_value, "email": {"$ne": data.email}}
        ):
            raise HTTPException(status_code=400, detail="Username already taken.")
        update_fields["username"] = username_value

    if data.license_plate is not None:
        # License plate cannot be empty - validate and use the provided value
        if data.license_plate.strip() == "":
            raise HTTPException(
                status_code=400, detail="License plate cannot be empty."
            )
        update_fields["license_plate"] = data.license_plate.strip()

    if data.phone_number is not None:
        # Phone number can be left empty (converts to null) or a valid value
        update_fields["phone_number"] = (
            None if data.phone_number.strip() == "" else data.phone_number.strip()
        )

    if data.address is not None:
        # Address can be left empty (converts to null) or a valid value
        update_fields["address"] = (
            None if data.address.strip() == "" else data.address.strip()
        )

    if not update_fields:
        raise HTTPException(status_code=400, detail="No fields to update.")
    user_collection.update_one({"email": data.email}, {"$set": update_fields})
    return {"msg": "Profile updated successfully."}


@router.get(
    "/profile",
    responses={
        200: {
            "description": "User profile fetched successfully.",
            "content": {
                "application/json": {
                    "example": {
                        "fullname": "abc",
                        "email": "abc@abc.com",
                        "phone_number": "-",
                        "license_plate": "-",
                        "address": "-",
                        "vehicle": None,
                        "failed_login_attempts": 0,
                        "suspend_until": 0,
                        "role": "user",
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
def get_profile(email: str):
    email = email.strip().lower()
    user = user_collection.find_one({"email": email}, {"_id": 0, "password": 0})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
