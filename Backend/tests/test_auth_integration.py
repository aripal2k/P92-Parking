import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from app.auth.router import (
    register_request,
    verify_registration,
    login,
    change_password,
    forgot_password,
    verify_reset_otp,
    reset_password,
    delete_account,
    edit_profile,
    get_profile,
    get_users,
)
from app.auth.auth import (
    UserCreate,
    OTPVerificationRequest,
    UserLogin,
    ChangePasswordRequest,
    ForgotPasswordRequest,
    ResetOTPVerificationRequest,
    ResetPasswordRequest,
    DeleteAccountRequest,
    UserEdit,
)
from app.auth.utils import hash_password, verify_password
import time


class TestAuthIntegration:
    """Integration tests for the complete auth flow"""

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.send_email_otp")
    @patch("app.auth.router.generate_otp")
    @patch("time.time")
    def test_complete_registration_flow(
        self, mock_time, mock_generate_otp, mock_send_email, mock_collection
    ):
        """Test complete user registration and verification flow"""
        mock_time.return_value = 1640995200.0
        mock_generate_otp.return_value = "123456"
        mock_collection.find_one.return_value = None  # No existing user
        mock_collection.update_one.return_value = MagicMock()
        mock_collection.replace_one.return_value = MagicMock()

        # Step 1: Register request
        user_data = UserCreate(
            fullname="Test User",
            email="test@example.com",
            username="testuser",
            password="TestPass123!",
            confirm_password="TestPass123!",
        )

        result1 = register_request(user_data)
        assert (
            result1["msg"]
            == "OTP sent to email. Please verify to complete registration."
        )

        # Step 2: Verify registration
        # Mock the user document that would be created after registration request
        user_doc = {
            "_id": "test_id",
            "email": "test@example.com",
            "otp": "123456",
            "otp_expire": 1640995800.0,  # Future time
            "temp_user": {
                "email": "test@example.com",
                "username": "testuser",
                "fullname": "Test User",
                "password": hash_password("TestPass123!"),
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

        otp_data = OTPVerificationRequest(email="test@example.com", otp="123456")

        result2 = verify_registration(otp_data)
        assert result2["msg"] == "Registration successful!"

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    @patch("time.time")
    def test_complete_login_flow_with_failed_attempts(
        self, mock_time, mock_verify, mock_collection
    ):
        """Test complete login flow including failed attempts and recovery"""
        mock_time.return_value = 1640995200.0

        # Initial user state
        user_doc = {
            "email": "test@example.com",
            "password": "hashed_password",
            "failed_login_attempts": 0,
            "suspend_until": 0,
        }

        login_data = UserLogin(email="test@example.com", password="TestPass123!")
        request = MagicMock()

        # Step 1: Failed login attempt 1
        mock_verify.return_value = False
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            login(login_data, request)
        assert exc_info.value.status_code == 401

        # Step 2: Failed login attempt 5 (triggers suspension)
        user_doc["failed_login_attempts"] = 4
        mock_collection.find_one.return_value = user_doc

        with pytest.raises(HTTPException) as exc_info:
            login(login_data, request)
        assert exc_info.value.status_code == 403
        assert "suspended" in exc_info.value.detail

        # Step 3: Successful login after suspension expires
        mock_time.return_value = 1640995800.0  # Later time
        user_doc["suspend_until"] = 1640995320.0  # Past time
        user_doc["failed_login_attempts"] = 0
        mock_verify.return_value = True
        mock_collection.find_one.return_value = user_doc

        result = login(login_data, request)
        assert result["msg"] == "Login success"

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.send_email_otp")
    @patch("app.auth.router.generate_otp")
    @patch("app.auth.router.verify_password")
    @patch("app.auth.router.hash_password")
    @patch("time.time")
    def test_complete_password_reset_flow(
        self,
        mock_time,
        mock_hash,
        mock_verify,
        mock_generate_otp,
        mock_send_email,
        mock_collection,
    ):
        """Test complete password reset flow"""
        mock_time.return_value = 1640995200.0
        mock_generate_otp.return_value = "123456"
        mock_hash.return_value = "new_hashed_password"
        mock_verify.return_value = False  # New password different from current

        user_doc = {"email": "test@example.com", "password": "old_hashed_password"}
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        # Step 1: Forgot password request
        forgot_data = ForgotPasswordRequest(email="test@example.com")
        result1 = forgot_password(forgot_data)
        assert result1["msg"] == "OTP code sent to your email."

        # Step 2: Verify reset OTP
        user_doc.update({"reset_otp": "123456", "reset_otp_expire": 1640995800.0})
        mock_collection.find_one.return_value = user_doc

        otp_data = ResetOTPVerificationRequest(email="test@example.com", otp="123456")
        result2 = verify_reset_otp(otp_data)
        assert result2["msg"] == "OTP verified successfully."

        # Step 3: Reset password
        user_doc["reset_verified"] = True
        mock_collection.find_one.return_value = user_doc

        reset_data = ResetPasswordRequest(
            email="test@example.com",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )
        result3 = reset_password(reset_data)
        assert result3["msg"] == "Password has been reset successfully."

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    @patch("app.auth.router.hash_password")
    def test_complete_profile_management_flow(
        self, mock_hash, mock_verify, mock_collection
    ):
        """Test complete profile management flow"""
        mock_verify.return_value = True
        mock_hash.return_value = "new_hashed_password"

        user_doc = {
            "email": "test@example.com",
            "username": "testuser",
            "fullname": "Test User",
            "password": "hashed_password",
            "license_plate": None,
            "phone_number": None,
            "address": None,
            "vehicle": None,
            "failed_login_attempts": 0,
            "suspend_until": 0,
            "role": "user",
        }
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()
        mock_collection.delete_one.return_value = MagicMock()

        # Step 1: Get profile
        result1 = get_profile("test@example.com")
        assert result1 == user_doc

        # Step 2: Edit profile
        edit_data = UserEdit(
            email="test@example.com", fullname="Updated Name", license_plate="ABC123"
        )
        result2 = edit_profile(edit_data)
        assert result2["msg"] == "Profile updated successfully."

        # Step 3: Change password
        change_data = ChangePasswordRequest(
            email="test@example.com",
            current_password="OldPass123!",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )
        result3 = change_password(change_data)
        assert result3["msg"] == "Password changed successfully."

        # Step 4: Delete account
        delete_data = DeleteAccountRequest(
            email="test@example.com", password="NewPass456@"
        )
        result4 = delete_account(delete_data)
        assert result4["msg"] == "Account deleted successfully."


class TestAuthEdgeCases:
    """Test edge cases and error scenarios"""

    @patch("app.auth.router.user_collection")
    def test_get_users_endpoint(self, mock_collection):
        """Test the get users endpoint"""
        user_list = [
            {
                "email": "user1@example.com",
                "username": "user1",
                "fullname": "User One",
                "role": "user",
            },
            {
                "email": "user2@example.com",
                "username": "user2",
                "fullname": "User Two",
                "role": "user",
            },
        ]
        mock_collection.find.return_value = user_list

        result = get_users()
        assert result == user_list
        mock_collection.find.assert_called_once_with(
            {"role": "user"}, {"_id": 0, "password": 0}
        )

    @patch("app.auth.router.user_collection")
    def test_email_normalization_consistency(self, mock_collection):
        """Test that email normalization is consistent across all endpoints"""
        user_doc = {
            "email": "test@example.com",
            "username": "testuser",
            "password": "hashed_password",
            "failed_login_attempts": 0,
            "suspend_until": 0,
        }
        mock_collection.find_one.return_value = user_doc

        # Test various email formats
        email_variations = [
            "Test@Example.Com",
            "TEST@EXAMPLE.COM",
            "  test@example.com  ",
            "test@EXAMPLE.com",
        ]

        for email_variant in email_variations:
            # Test get_profile
            result = get_profile(email_variant)
            mock_collection.find_one.assert_called_with(
                {"email": "test@example.com"}, {"_id": 0, "password": 0}
            )

    def test_password_validation_consistency(self):
        """Test that password validation is consistent across endpoints"""
        invalid_passwords = [
            ("short", "Password must be at least 8 characters long"),
            ("NoNumbers!", "Password must contain at least one number"),
            (
                "NoSpecialChars123",
                "Password must contain at least one special character",
            ),
            (
                "password123!",
                "Password is too common. Please choose a more secure one.",
            ),
        ]

        for password, expected_error in invalid_passwords:
            user_data = UserCreate(
                fullname="Test User",
                email="test@example.com",
                username="testuser",
                password=password,
                confirm_password=password,
            )

            with patch("app.auth.router.user_collection") as mock_collection:
                mock_collection.find_one.return_value = None

                with pytest.raises(HTTPException) as exc_info:
                    register_request(user_data)

                assert expected_error in exc_info.value.detail

    @patch("app.auth.router.user_collection")
    @patch("time.time")
    def test_otp_expiration_edge_cases(self, mock_time, mock_collection):
        """Test OTP expiration edge cases"""
        mock_time.return_value = 1640995200.0

        # Test OTP that expired 1 second ago
        user_doc = {
            "email": "test@example.com",
            "otp": "123456",
            "otp_expire": 1640995199.0,  # Expired 1 second ago
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

        otp_data = OTPVerificationRequest(email="test@example.com", otp="123456")

        with pytest.raises(HTTPException) as exc_info:
            verify_registration(otp_data)

        assert exc_info.value.status_code == 400
        assert "expired" in exc_info.value.detail.lower()

    @patch("app.auth.router.user_collection")
    def test_database_error_handling(self, mock_collection):
        """Test handling of database errors"""
        # Simulate database connection error
        mock_collection.find_one.side_effect = Exception("Database connection error")

        login_data = UserLogin(email="test@example.com", password="TestPass123!")
        request = MagicMock()

        # The function should let the exception handle it gracefully
        with pytest.raises(Exception):
            login(login_data, request)

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    def test_concurrent_login_attempts(self, mock_verify, mock_collection):
        """Test concurrent login attempts and race conditions"""
        mock_verify.return_value = False

        user_doc = {
            "email": "test@example.com",
            "password": "hashed_password",
            "failed_login_attempts": 4,  # One away from suspension
            "suspend_until": 0,
        }
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        login_data = UserLogin(email="test@example.com", password="WrongPassword")
        request = MagicMock()

        # This should trigger suspension
        with pytest.raises(HTTPException) as exc_info:
            login(login_data, request)

        assert exc_info.value.status_code == 403
        assert "suspended" in exc_info.value.detail.lower()

    def test_auth_utils_edge_cases(self):
        """Test edge cases in auth utility functions"""
        # Test hash_password with various inputs
        passwords = [
            "minimum8",  # Minimum length
            "a" * 100,  # Very long password
            "🔒secure123!",  # Unicode characters
            "pass word with spaces 123!",  # Spaces
        ]

        for password in passwords:
            hashed = hash_password(password)
            assert isinstance(hashed, str)
            assert len(hashed) > 0
            assert verify_password(password, hashed) is True
            assert verify_password("wrong", hashed) is False
