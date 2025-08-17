import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from app.auth.router import login
from app.auth.auth import UserLogin
from app.auth.utils import hash_password

# test cases for user login
# APIs:
# /auth/login


class TestUserLogin:
    """Test cases for user login functionality"""

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    @patch("time.time")
    def test_login_success(self, mock_time, mock_verify, mock_collection):
        """Test successful login"""
        mock_time.return_value = 1640995200.0
        mock_verify.return_value = True

        user_doc = {
            "email": "test@example.com",
            "password": "hashed_password",
            "failed_login_attempts": 0,
            "suspend_until": 0,
        }
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        login_data = UserLogin(email="test@example.com", password="TestPass123!")

        # Mock request object
        request = MagicMock()

        result = login(login_data, request)

        assert result["msg"] == "Login success"
        # check that failed attempts are reset on successful login
        mock_collection.update_one.assert_called_with(
            {"email": "test@example.com"},
            {"$set": {"failed_login_attempts": 0, "suspend_until": 0}},
        )

    @patch("app.auth.router.user_collection")
    def test_login_email_not_registered(self, mock_collection):
        """Test login with unregistered email"""
        mock_collection.find_one.return_value = None

        login_data = UserLogin(email="nonexistent@example.com", password="TestPass123!")

        request = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            login(login_data, request)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Email is not registered."

    @patch("app.auth.router.user_collection")
    @patch("time.time")
    def test_login_account_suspended(self, mock_time, mock_collection):
        """Test login with suspended account"""
        mock_time.return_value = 1640995200.0

        user_doc = {
            "email": "test@example.com",
            "password": "hashed_password",
            "failed_login_attempts": 0,
            "suspend_until": 1640995800.0,  # Suspended until future time
        }
        mock_collection.find_one.return_value = user_doc

        login_data = UserLogin(email="test@example.com", password="TestPass123!")

        request = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            login(login_data, request)

        assert exc_info.value.status_code == 403
        assert (
            exc_info.value.detail
            == "Account is suspended, please try again in 30 minutes."
        )

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    @patch("time.time")
    def test_login_wrong_password_first_attempt(
        self, mock_time, mock_verify, mock_collection
    ):
        """Test login with wrong password - first failed attempt"""
        mock_time.return_value = 1640995200.0
        mock_verify.return_value = False

        user_doc = {
            "email": "test@example.com",
            "password": "hashed_password",
            "failed_login_attempts": 0,
            "suspend_until": 0,
        }
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        login_data = UserLogin(email="test@example.com", password="WrongPassword123!")

        request = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            login(login_data, request)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Password or email is incorrect."

        # Verify failed attempts are incremented
        mock_collection.update_one.assert_called_with(
            {"email": "test@example.com"}, {"$set": {"failed_login_attempts": 1}}
        )

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    @patch("time.time")
    def test_login_wrong_password_fifth_attempt_suspension(
        self, mock_time, mock_verify, mock_collection
    ):
        """Test login with wrong password - fifth attempt triggers suspension"""
        mock_time.return_value = 1640995200.0
        mock_verify.return_value = False

        user_doc = {
            "email": "test@example.com",
            "password": "hashed_password",
            "failed_login_attempts": 4,  # This will be the 5th attempt
            "suspend_until": 0,
        }
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        login_data = UserLogin(email="test@example.com", password="WrongPassword123!")

        request = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            login(login_data, request)

        assert exc_info.value.status_code == 403
        assert (
            exc_info.value.detail
            == "Account is suspended, please try again in 30 minutes."
        )

        # Verify account is suspended and attempts reset
        expected_suspend_until = 1640995200.0 + 2 * 60  # 2 minutes in the future
        mock_collection.update_one.assert_called_with(
            {"email": "test@example.com"},
            {
                "$set": {
                    "suspend_until": expected_suspend_until,
                    "failed_login_attempts": 0,
                }
            },
        )

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    @patch("time.time")
    def test_login_wrong_password_multiple_attempts(
        self, mock_time, mock_verify, mock_collection
    ):
        """Test login with wrong password - multiple attempts but under limit"""
        mock_time.return_value = 1640995200.0
        mock_verify.return_value = False

        user_doc = {
            "email": "test@example.com",
            "password": "hashed_password",
            "failed_login_attempts": 2,  # This will be the 3rd attempt
            "suspend_until": 0,
        }
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        login_data = UserLogin(email="test@example.com", password="WrongPassword123!")

        request = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            login(login_data, request)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Password or email is incorrect."

        # Verify failed attempts are incremented but no suspension
        mock_collection.update_one.assert_called_with(
            {"email": "test@example.com"}, {"$set": {"failed_login_attempts": 3}}
        )

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    @patch("time.time")
    def test_login_after_suspension_expires(
        self, mock_time, mock_verify, mock_collection
    ):
        """Test successful login after suspension period expires"""
        mock_time.return_value = 1640995200.0
        mock_verify.return_value = True

        user_doc = {
            "email": "test@example.com",
            "password": "hashed_password",
            "failed_login_attempts": 0,
            "suspend_until": 1640994600.0,  # Suspension expired
        }
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        login_data = UserLogin(email="test@example.com", password="TestPass123!")

        request = MagicMock()

        result = login(login_data, request)

        assert result["msg"] == "Login success"

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    def test_login_email_case_insensitive(self, mock_verify, mock_collection):
        """Test that email is handled case-insensitively"""
        mock_verify.return_value = True

        user_doc = {
            "email": "test@example.com",  # saved as lowercase in database
            "password": "hashed_password",
            "failed_login_attempts": 0,
            "suspend_until": 0,
        }
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        login_data = UserLogin(
            email="TEST@EXAMPLE.COM", password="TestPass123!"  # Uppercase input
        )

        request = MagicMock()

        result = login(login_data, request)

        assert result["msg"] == "Login success"
        # Verify the email was converted to lowercase for database query
        mock_collection.find_one.assert_called_with({"email": "test@example.com"})
