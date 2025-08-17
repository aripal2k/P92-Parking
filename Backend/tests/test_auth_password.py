import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from app.auth.router import (
    change_password,
    forgot_password,
    verify_reset_otp,
    reset_password,
)
from app.auth.auth import (
    ChangePasswordRequest,
    ForgotPasswordRequest,
    ResetOTPVerificationRequest,
    ResetPasswordRequest,
)
from app.auth.utils import hash_password

# 2 parts: Change Password and Reset Password
# APIs:
# /auth/change-password
# /auth/forgot-password
# /auth/verify-reset-otp
# /auth/reset-password


class TestChangePassword:
    """Test cases for change password functionality"""

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    @patch("app.auth.router.hash_password")
    def test_change_password_success(self, mock_hash, mock_verify, mock_collection):
        """Test successful password change"""
        mock_verify.return_value = True
        mock_hash.return_value = "new_hashed_password"

        user_doc = {"email": "test@example.com", "password": "old_hashed_password"}
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        change_data = ChangePasswordRequest(
            email="test@example.com",
            current_password="OldPass123!",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        result = change_password(change_data)

        assert result["msg"] == "Password changed successfully."
        mock_collection.update_one.assert_called_once_with(
            {"email": "test@example.com"}, {"$set": {"password": "new_hashed_password"}}
        )

    @patch("app.auth.router.user_collection")
    def test_change_password_user_not_found(self, mock_collection):
        """Test password change with non-existent user"""
        mock_collection.find_one.return_value = None

        change_data = ChangePasswordRequest(
            email="nonexistent@example.com",
            current_password="OldPass123!",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        with pytest.raises(HTTPException) as exc_info:
            change_password(change_data)

        assert exc_info.value.status_code == 404
        assert exc_info.value.detail == "User not found."

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    def test_change_password_incorrect_current_password(
        self, mock_verify, mock_collection
    ):
        """Test password change with incorrect current password"""
        mock_verify.return_value = False

        user_doc = {"email": "test@example.com", "password": "old_hashed_password"}
        mock_collection.find_one.return_value = user_doc

        change_data = ChangePasswordRequest(
            email="test@example.com",
            current_password="WrongPass123!",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        with pytest.raises(HTTPException) as exc_info:
            change_password(change_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Current password is incorrect."

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    def test_change_password_mismatch(self, mock_verify, mock_collection):
        """Test password change with new password mismatch"""
        mock_verify.return_value = True

        user_doc = {"email": "test@example.com", "password": "old_hashed_password"}
        mock_collection.find_one.return_value = user_doc

        change_data = ChangePasswordRequest(
            email="test@example.com",
            current_password="OldPass123!",
            new_password="NewPass456@",
            confirm_new_password="DifferentPass789#",
        )

        with pytest.raises(HTTPException) as exc_info:
            change_password(change_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "New password and confirmation do not match."

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    def test_change_password_same_as_current(self, mock_verify, mock_collection):
        """Test password change with new password same as current"""
        mock_verify.return_value = True

        user_doc = {"email": "test@example.com", "password": "old_hashed_password"}
        mock_collection.find_one.return_value = user_doc

        change_data = ChangePasswordRequest(
            email="test@example.com",
            current_password="OldPass123!",
            new_password="OldPass123!",  # Same as current
            confirm_new_password="OldPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            change_password(change_data)

        assert exc_info.value.status_code == 400
        assert (
            exc_info.value.detail
            == "New password cannot be the same as the current password."
        )

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    def test_change_password_validation_errors(self, mock_verify, mock_collection):
        """Test password change with various validation errors"""
        mock_verify.return_value = True

        user_doc = {"email": "test@example.com", "password": "old_hashed_password"}
        mock_collection.find_one.return_value = user_doc

        # Test too short password
        change_data = ChangePasswordRequest(
            email="test@example.com",
            current_password="OldPass123!",
            new_password="Short1!",
            confirm_new_password="Short1!",
        )

        with pytest.raises(HTTPException) as exc_info:
            change_password(change_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Password must be at least 8 characters long"


class TestForgotPassword:
    """Test cases for forgot password functionality"""

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.send_email_otp")
    @patch("app.auth.router.generate_otp")
    @patch("time.time")
    def test_forgot_password_success(
        self, mock_time, mock_generate_otp, mock_send_email, mock_collection
    ):
        """Test successful forgot password request"""
        mock_time.return_value = 1640995200.0
        mock_generate_otp.return_value = "123456"

        user_doc = {"email": "test@example.com", "password": "hashed_password"}
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        forgot_data = ForgotPasswordRequest(email="test@example.com")

        result = forgot_password(forgot_data)

        assert result["msg"] == "OTP code sent to your email."
        mock_send_email.assert_called_once_with("test@example.com", "123456")

        # Verify OTP data is stored
        expected_expire_time = 1640995200.0 + 10 * 60  # 10 minutes
        mock_collection.update_one.assert_called_once_with(
            {"email": "test@example.com"},
            {"$set": {"reset_otp": "123456", "reset_otp_expire": expected_expire_time}},
        )

    @patch("app.auth.router.user_collection")
    def test_forgot_password_user_not_found(self, mock_collection):
        """Test forgot password with non-existent user"""
        mock_collection.find_one.return_value = None

        forgot_data = ForgotPasswordRequest(email="nonexistent@example.com")

        with pytest.raises(HTTPException) as exc_info:
            forgot_password(forgot_data)

        assert exc_info.value.status_code == 404
        assert exc_info.value.detail == "User not found."


class TestVerifyResetOTP:
    """Test cases for reset OTP verification"""

    @patch("app.auth.router.user_collection")
    @patch("time.time")
    def test_verify_reset_otp_success(self, mock_time, mock_collection):
        """Test successful reset OTP verification"""
        mock_time.return_value = 1640995200.0

        user_doc = {
            "email": "test@example.com",
            "reset_otp": "123456",
            "reset_otp_expire": 1640995800.0,  # 10min later
        }
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        otp_data = ResetOTPVerificationRequest(email="test@example.com", otp="123456")

        result = verify_reset_otp(otp_data)

        assert result["msg"] == "OTP verified successfully."
        mock_collection.update_one.assert_called_once_with(
            {"email": "test@example.com"}, {"$set": {"reset_verified": True}}
        )

    @patch("app.auth.router.user_collection")
    def test_verify_reset_otp_user_not_found(self, mock_collection):
        """Test reset OTP verification with non-existent user"""
        mock_collection.find_one.return_value = None

        otp_data = ResetOTPVerificationRequest(
            email="nonexistent@example.com", otp="123456"
        )

        with pytest.raises(HTTPException) as exc_info:
            verify_reset_otp(otp_data)

        assert exc_info.value.status_code == 404
        assert exc_info.value.detail == "User not found."

    @patch("app.auth.router.user_collection")
    def test_verify_reset_otp_no_otp_requested(self, mock_collection):
        """Test reset OTP verification when no OTP was requested"""
        user_doc = {
            "email": "test@example.com"
            # No reset_otp fields
        }
        mock_collection.find_one.return_value = user_doc

        otp_data = ResetOTPVerificationRequest(email="test@example.com", otp="123456")

        with pytest.raises(HTTPException) as exc_info:
            verify_reset_otp(otp_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "No OTP requested or OTP expired."

    @patch("app.auth.router.user_collection")
    @patch("time.time")
    def test_verify_reset_otp_expired(self, mock_time, mock_collection):
        """Test reset OTP verification with expired OTP"""
        mock_time.return_value = 1640995200.0

        user_doc = {
            "email": "test@example.com",
            "reset_otp": "123456",
            "reset_otp_expire": 1640994600.0,  # Past time
        }
        mock_collection.find_one.return_value = user_doc

        otp_data = ResetOTPVerificationRequest(email="test@example.com", otp="123456")

        with pytest.raises(HTTPException) as exc_info:
            verify_reset_otp(otp_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "OTP code has expired."

    @patch("app.auth.router.user_collection")
    @patch("time.time")
    def test_verify_reset_otp_incorrect(self, mock_time, mock_collection):
        """Test reset OTP verification with incorrect OTP"""
        mock_time.return_value = 1640995200.0

        user_doc = {
            "email": "test@example.com",
            "reset_otp": "123456",
            "reset_otp_expire": 1640995800.0,
        }
        mock_collection.find_one.return_value = user_doc

        otp_data = ResetOTPVerificationRequest(
            email="test@example.com", otp="654321"  # Wrong OTP
        )

        with pytest.raises(HTTPException) as exc_info:
            verify_reset_otp(otp_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "OTP code is incorrect."


class TestResetPassword:
    """Test cases for password reset functionality"""

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    @patch("app.auth.router.hash_password")
    def test_reset_password_success(self, mock_hash, mock_verify, mock_collection):
        """Test successful password reset"""
        mock_verify.return_value = False  # New password different from curr
        mock_hash.return_value = "new_hashed_password"

        user_doc = {
            "email": "test@example.com",
            "password": "old_hashed_password",
            "reset_verified": True,
        }
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        reset_data = ResetPasswordRequest(
            email="test@example.com",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        result = reset_password(reset_data)

        assert result["msg"] == "Password has been reset successfully."
        mock_collection.update_one.assert_called_once_with(
            {"email": "test@example.com"},
            {
                "$set": {"password": "new_hashed_password"},
                "$unset": {
                    "reset_otp": "",
                    "reset_otp_expire": "",
                    "reset_verified": "",
                },
            },
        )

    @patch("app.auth.router.user_collection")
    def test_reset_password_user_not_found(self, mock_collection):
        """Test password reset with non-existent user"""
        mock_collection.find_one.return_value = None

        reset_data = ResetPasswordRequest(
            email="nonexistent@example.com",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        with pytest.raises(HTTPException) as exc_info:
            reset_password(reset_data)

        assert exc_info.value.status_code == 404
        assert exc_info.value.detail == "User not found."

    @patch("app.auth.router.user_collection")
    def test_reset_password_otp_not_verified(self, mock_collection):
        """Test password reset without OTP verification"""
        user_doc = {
            "email": "test@example.com",
            "password": "old_hashed_password",
            # No reset_verified field
        }
        mock_collection.find_one.return_value = user_doc

        reset_data = ResetPasswordRequest(
            email="test@example.com",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        with pytest.raises(HTTPException) as exc_info:
            reset_password(reset_data)

        assert exc_info.value.status_code == 400
        assert (
            exc_info.value.detail
            == "OTP verification required before resetting password."
        )

    @patch("app.auth.router.user_collection")
    def test_reset_password_mismatch(self, mock_collection):
        """Test password reset with password mismatch"""
        user_doc = {
            "email": "test@example.com",
            "password": "old_hashed_password",
            "reset_verified": True,
        }
        mock_collection.find_one.return_value = user_doc

        reset_data = ResetPasswordRequest(
            email="test@example.com",
            new_password="NewPass456@",
            confirm_new_password="DifferentPass789#",
        )

        with pytest.raises(HTTPException) as exc_info:
            reset_password(reset_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "New password and confirmation do not match."

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    def test_reset_password_same_as_current(self, mock_verify, mock_collection):
        """Test password reset with new password same as current"""
        mock_verify.return_value = True  # Same as current password

        user_doc = {
            "email": "test@example.com",
            "password": "old_hashed_password",
            "reset_verified": True,
        }
        mock_collection.find_one.return_value = user_doc

        reset_data = ResetPasswordRequest(
            email="test@example.com",
            new_password="OldPass123!",
            confirm_new_password="OldPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            reset_password(reset_data)

        assert exc_info.value.status_code == 400
        assert (
            exc_info.value.detail
            == "New password cannot be the same as the current password."
        )

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    def test_reset_password_validation_errors(self, mock_verify, mock_collection):
        """Test password reset with validation errors (password too common)"""
        mock_verify.return_value = False

        user_doc = {
            "email": "test@example.com",
            "password": "old_hashed_password",
            "reset_verified": True,
        }
        mock_collection.find_one.return_value = user_doc

        # Test common password
        reset_data = ResetPasswordRequest(
            email="test@example.com",
            new_password="password123!",
            confirm_new_password="password123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            reset_password(reset_data)

        assert exc_info.value.status_code == 400
        assert (
            exc_info.value.detail
            == "Password is too common. Please choose a more secure one."
        )
