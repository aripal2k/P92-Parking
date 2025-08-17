import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from app.auth.router import register_request, verify_registration
from app.auth.auth import UserCreate, OTPVerificationRequest

# 2 parts: register request & verify registration
# APIs:
# /auth/register-request
# /auth/verify-registration


class TestUserRegistration:
    """Test cases for user registration functionality"""

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.send_email_otp")
    @patch("app.auth.router.generate_otp")
    @patch("time.time")
    # register request success
    def test_register_request_success(
        self, mock_time, mock_generate_otp, mock_send_email, mock_collection
    ):
        """Test successful registration request"""
        # Setup mocks
        mock_time.return_value = 1640995200.0
        mock_generate_otp.return_value = "123456"
        mock_collection.find_one.return_value = None  # No existing user
        mock_collection.update_one.return_value = MagicMock()

        user_data = UserCreate(
            fullname="Test User",
            email="test@example.com",
            username="testuser",
            password="TestPass123!",
            confirm_password="TestPass123!",
        )

        result = register_request(user_data)

        assert (
            result["msg"]
            == "OTP sent to email. Please verify to complete registration."
        )
        mock_send_email.assert_called_once_with("test@example.com", "123456")
        mock_collection.update_one.assert_called_once()

    # register request empty username (error)
    @patch("app.auth.router.user_collection")
    def test_register_request_empty_username(self, mock_collection):
        """Test registration with empty username"""
        user_data = UserCreate(
            fullname="Test User",
            email="test@example.com",
            username=" ",  # Empty username
            password="TestPass123!",
            confirm_password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            register_request(user_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Username cannot be empty"

    # register request empty fullname (error)
    @patch("app.auth.router.user_collection")
    def test_register_request_empty_fullname(self, mock_collection):
        """Test registration with empty fullname"""
        user_data = UserCreate(
            fullname="   ",  # Empty fullname
            email="test@example.com",
            username="testuser",
            password="TestPass123!",
            confirm_password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            register_request(user_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Full name cannot be empty"

    # register request password is too short (error)
    @patch("app.auth.router.user_collection")
    def test_register_request_short_password(self, mock_collection):
        """Test registration with password too short"""
        user_data = UserCreate(
            fullname="Test User",
            email="test@example.com",
            username="testuser",
            password="Test1!",  # Too short
            confirm_password="Test1!",
        )

        with pytest.raises(HTTPException) as exc_info:
            register_request(user_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Password must be at least 8 characters long"

    # register request password does not contain a number (error)
    @patch("app.auth.router.user_collection")
    def test_register_request_password_no_number(self, mock_collection):
        """Test registration with password missing number"""
        user_data = UserCreate(
            fullname="Test User",
            email="test@example.com",
            username="testuser",
            password="TestPassword!",  # No number
            confirm_password="TestPassword!",
        )

        with pytest.raises(HTTPException) as exc_info:
            register_request(user_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Password must contain at least one number"

    @patch("app.auth.router.user_collection")
    def test_register_request_password_no_special_char(self, mock_collection):
        """Test registration with password missing special character"""
        user_data = UserCreate(
            fullname="Test User",
            email="test@example.com",
            username="testuser",
            password="TestPassword123",  # No special character
            confirm_password="TestPassword123",
        )

        with pytest.raises(HTTPException) as exc_info:
            register_request(user_data)

        assert exc_info.value.status_code == 400
        assert (
            exc_info.value.detail
            == "Password must contain at least one special character"
        )

    @patch("app.auth.router.user_collection")
    def test_register_request_password_mismatch(self, mock_collection):
        """Test registration with password mismatch"""
        user_data = UserCreate(
            fullname="Test User",
            email="test@example.com",
            username="testuser",
            password="TestPass123!",
            confirm_password="DifferentPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            register_request(user_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Passwords do not match"

    @patch("app.auth.router.user_collection")
    def test_register_request_common_password(self, mock_collection):
        """Test registration with common password"""
        user_data = UserCreate(
            fullname="Test User",
            email="test@example.com",
            username="testuser",
            password="password123!",  # Common password
            confirm_password="password123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            register_request(user_data)

        assert exc_info.value.status_code == 400
        assert (
            exc_info.value.detail
            == "Password is too common. Please choose a more secure one."
        )

    @patch("app.auth.router.user_collection")
    def test_register_request_email_already_registered(self, mock_collection):
        """Test registration with already registered email"""
        mock_collection.find_one.return_value = {"email": "test@example.com"}

        user_data = UserCreate(
            fullname="Test User",
            email="test@example.com",
            username="testuser",
            password="TestPass123!",
            confirm_password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            register_request(user_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Email already registered"

    @patch("app.auth.router.user_collection")
    def test_register_request_username_taken(self, mock_collection):
        """Test registration with taken username"""

        def side_effect(query):
            if "email" in query:
                return None  # Email not registered
            elif "username" in query:
                return {"username": "testuser"}  # Username taken

        mock_collection.find_one.side_effect = side_effect

        user_data = UserCreate(
            fullname="Test User",
            email="test@example.com",
            username="testuser",
            password="TestPass123!",
            confirm_password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            register_request(user_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Username already taken"

    # register request check email case sensitivity (success)
    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.send_email_otp")
    @patch("app.auth.router.generate_otp")
    @patch("time.time")
    def test_register_request_email_case_sensitivity(
        self, mock_time, mock_generate_otp, mock_send_email, mock_collection
    ):
        """Test that registration request handles email case sensitivity correctly"""
        mock_time.return_value = 1640995200.0
        mock_generate_otp.return_value = "123456"
        mock_collection.find_one.return_value = None  # No existing user
        mock_collection.update_one.return_value = MagicMock()

        # Test with uppercase email
        user_data = UserCreate(
            fullname="Test User",
            email="TEST@EXAMPLE.COM",  # Uppercase email
            username="testuser",
            password="TestPass123!",
            confirm_password="TestPass123!",
        )

        result = register_request(user_data)

        assert (
            result["msg"]
            == "OTP sent to email. Please verify to complete registration."
        )

        # Verify that email was normalized to lowercase in database
        mock_collection.find_one.assert_any_call({"email": "test@example.com"})
        mock_collection.update_one.assert_called_once()

        # Verify email sent to normalized address
        mock_send_email.assert_called_once_with("test@example.com", "123456")

        # Check the update_one call arguments to ensure email is normalized
        update_call_args = mock_collection.update_one.call_args
        assert update_call_args[0][0] == {
            "email": "test@example.com"
        }  # Query uses lowercase

        # Verify temp_user data has normalized email
        update_data = update_call_args[0][1]["$set"]
        assert update_data["temp_user"]["email"] == "test@example.com"

    @patch("app.auth.router.user_collection")
    # register request email case conflict (error)
    def test_register_request_email_case_conflict(self, mock_collection):
        """Test that emails with different cases are treated as the same email"""
        # Existing user with the same email (but in lowercase)
        existing_user = {"email": "test@example.com"}
        mock_collection.find_one.return_value = existing_user

        # Try to register with uppercase version of same email
        user_data = UserCreate(
            fullname="Test User",
            email="TEST@EXAMPLE.COM",  # Different case, same email
            username="testuser2",
            password="TestPass123!",
            confirm_password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            register_request(user_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Email already registered"

        # Check that the database was queried with normalized lowercase email
        mock_collection.find_one.assert_called_with({"email": "test@example.com"})

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.send_email_otp")
    @patch("app.auth.router.generate_otp")
    @patch("time.time")
    # register request email with whitespace (success)
    def test_register_request_email_with_whitespace(
        self, mock_time, mock_generate_otp, mock_send_email, mock_collection
    ):
        """Test that registration handles email with leading/trailing whitespace"""
        mock_time.return_value = 1640995200.0
        mock_generate_otp.return_value = "123456"
        mock_collection.find_one.return_value = None
        mock_collection.update_one.return_value = MagicMock()

        # Test with email containing whitespace
        user_data = UserCreate(
            fullname="Test User",
            email="  TEST@EXAMPLE.COM  ",  # Whitespace + uppercase
            username="testuser",
            password="TestPass123!",
            confirm_password="TestPass123!",
        )

        result = register_request(user_data)

        assert (
            result["msg"]
            == "OTP sent to email. Please verify to complete registration."
        )

        # Verify email was trimmed and normalized
        mock_collection.find_one.assert_any_call({"email": "test@example.com"})
        mock_send_email.assert_called_once_with("test@example.com", "123456")

        # Verify normalized email in database update
        update_call_args = mock_collection.update_one.call_args
        update_data = update_call_args[0][1]["$set"]
        assert update_data["temp_user"]["email"] == "test@example.com"


class TestVerifyRegistration:
    """Test cases for registration verification"""

    @patch("app.auth.router.user_collection")
    @patch("time.time")
    def test_verify_registration_success(self, mock_time, mock_collection):
        """Test successful registration verification"""
        mock_time.return_value = 1640995200.0

        # Mock user document with valid OTP
        user_doc = {
            "_id": "test_id",
            "email": "test@example.com",
            "otp": "123456",
            "otp_expire": 1640995800.0,
            "temp_user": {
                "email": "test@example.com",
                "username": "testuser",
                "fullname": "Test User",
                "password": "hashed_password",
                "vehicle": None,
                "license_plate": None,
                "phone_number": None,
                "address": None,
                "failed_login_attempts": 0,
                "suspend_until": 0,
                "role": "user",
            },
        }

        mock_collection.find_one.return_value = user_doc
        mock_collection.replace_one.return_value = MagicMock()

        otp_data = OTPVerificationRequest(email="test@example.com", otp="123456")

        result = verify_registration(otp_data)

        assert result["msg"] == "Registration successful!"
        mock_collection.replace_one.assert_called_once()

    @patch("app.auth.router.user_collection")
    def test_verify_registration_user_not_found(self, mock_collection):
        """Test verification with non-existent user"""
        mock_collection.find_one.return_value = None

        otp_data = OTPVerificationRequest(email="nonexistent@example.com", otp="123456")

        with pytest.raises(HTTPException) as exc_info:
            verify_registration(otp_data)

        assert exc_info.value.status_code == 404
        assert exc_info.value.detail == "User not found"

    @patch("app.auth.router.user_collection")
    def test_verify_registration_no_otp_requested(self, mock_collection):
        """Test verification when no OTP was requested"""
        user_doc = {"email": "test@example.com"}  # No OTP fields
        mock_collection.find_one.return_value = user_doc

        otp_data = OTPVerificationRequest(email="test@example.com", otp="123456")

        with pytest.raises(HTTPException) as exc_info:
            verify_registration(otp_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "No OTP requested or OTP expired."

    @patch("app.auth.router.user_collection")
    @patch("time.time")
    def test_verify_registration_expired_otp(self, mock_time, mock_collection):
        """Test verification with expired OTP"""
        mock_time.return_value = 1640995200.0

        user_doc = {
            "email": "test@example.com",
            "otp": "123456",
            "otp_expire": 1640994600.0,  # 10 minutes in past
            "temp_user": {},
        }
        mock_collection.find_one.return_value = user_doc

        otp_data = OTPVerificationRequest(email="test@example.com", otp="123456")

        with pytest.raises(HTTPException) as exc_info:
            verify_registration(otp_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "OTP code has expired."

    @patch("app.auth.router.user_collection")
    @patch("time.time")
    def test_verify_registration_incorrect_otp(self, mock_time, mock_collection):
        """Test verification with incorrect OTP"""
        mock_time.return_value = 1640995200.0

        user_doc = {
            "email": "test@example.com",
            "otp": "123456",
            "otp_expire": 1640995800.0,
            "temp_user": {},
        }
        mock_collection.find_one.return_value = user_doc

        otp_data = OTPVerificationRequest(
            email="test@example.com", otp="654321"  # Wrong OTP
        )

        with pytest.raises(HTTPException) as exc_info:
            verify_registration(otp_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "OTP code is incorrect."

    @patch("app.auth.router.user_collection")
    @patch("time.time")
    def test_verify_registration_no_temp_user(self, mock_time, mock_collection):
        """Test verification when no temp user data exists"""
        mock_time.return_value = 1640995200.0

        user_doc = {
            "email": "test@example.com",
            "otp": "123456",
            "otp_expire": 1640995800.0,
            # No temp_user field
        }
        mock_collection.find_one.return_value = user_doc

        otp_data = OTPVerificationRequest(email="test@example.com", otp="123456")

        with pytest.raises(HTTPException) as exc_info:
            verify_registration(otp_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "No pending registration found."
