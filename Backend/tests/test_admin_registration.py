import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from app.admin.router import register_admin
from app.admin.router import AdminRegisterRequest
import random
import string

# test cases for admin registration
# APIs:
# /admin/register


class TestAdminRegistration:
    """Test cases for admin registration functionality"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.generate_username")
    @patch("app.admin.router.generate_password")
    def test_admin_register_success(
        self, mock_generate_password, mock_generate_username, mock_collection
    ):
        """Test successful admin registration"""
        # Setup mocks
        mock_generate_username.return_value = "abcd1234"
        mock_generate_password.return_value = "TempPass123!"
        mock_collection.find_one.return_value = None  # No existing user
        mock_collection.insert_one.return_value = MagicMock()

        request_data = AdminRegisterRequest(
            email="admin@example.com", keyID="Westfield Sydney"
        )

        result = register_admin(request_data)

        assert result["msg"] == "Admin registered successfully"
        assert result["username"] == "abcd1234"
        assert result["password"] == "TempPass123!"

        # Verify database operations
        # Note: find_one is called twice - once for email check, once for username collision check
        assert mock_collection.find_one.call_count >= 1
        mock_collection.insert_one.assert_called_once()

        # Verify inserted data structure
        insert_call_args = mock_collection.insert_one.call_args[0][0]
        assert insert_call_args["email"] == "admin@example.com"
        assert insert_call_args["username"] == "abcd1234"
        assert insert_call_args["password"] == "TempPass123!"
        assert insert_call_args["role"] == "admin"
        assert insert_call_args["keyID"] == "Westfield Sydney"

    @patch("app.admin.router.user_collection")
    def test_admin_register_email_already_registered(self, mock_collection):
        """Test admin registration with already registered email"""
        mock_collection.find_one.return_value = {"email": "admin@example.com"}

        request_data = AdminRegisterRequest(
            email="admin@example.com", keyID="Westfield Sydney"
        )

        with pytest.raises(HTTPException) as exc_info:
            register_admin(request_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Email already registered"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.generate_username")
    @patch("app.admin.router.generate_password")
    def test_admin_register_email_case_sensitivity(
        self, mock_generate_password, mock_generate_username, mock_collection
    ):
        """Test that admin registration handles email case sensitivity correctly"""
        mock_generate_username.return_value = "abcd1234"
        mock_generate_password.return_value = "TempPass123!"
        mock_collection.find_one.return_value = None
        mock_collection.insert_one.return_value = MagicMock()

        # Test with uppercase email
        request_data = AdminRegisterRequest(
            email="ADMIN@EXAMPLE.COM", keyID="Westfield Sydney"  # Uppercase email
        )

        result = register_admin(request_data)

        assert result["msg"] == "Admin registered successfully"

        # Verify that email was normalized to lowercase in database check
        # Check that at least one call was made with the normalized email
        calls = mock_collection.find_one.call_args_list
        email_calls = [
            call for call in calls if call[0][0].get("email") == "admin@example.com"
        ]
        assert len(email_calls) >= 1

        # Verify email is stored normalized in database
        insert_call_args = mock_collection.insert_one.call_args[0][0]
        assert insert_call_args["email"] == "admin@example.com"

    @patch("app.admin.router.user_collection")
    def test_admin_register_email_case_conflict(self, mock_collection):
        """Test that emails with different cases are treated as the same email"""
        # Existing user with lowercase email
        existing_user = {"email": "admin@example.com"}
        mock_collection.find_one.return_value = existing_user

        # Try to register with uppercase version of same email
        request_data = AdminRegisterRequest(
            email="ADMIN@EXAMPLE.COM",  # Different case, same email
            keyID="Westfield Sydney",
        )

        with pytest.raises(HTTPException) as exc_info:
            register_admin(request_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Email already registered"

        # Check that the database was queried with normalized lowercase email
        mock_collection.find_one.assert_called_with({"email": "admin@example.com"})

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.generate_username")
    @patch("app.admin.router.generate_password")
    def test_admin_register_email_with_whitespace(
        self, mock_generate_password, mock_generate_username, mock_collection
    ):
        """Test that admin registration handles email with leading/trailing whitespace"""
        mock_generate_username.return_value = "abcd1234"
        mock_generate_password.return_value = "TempPass123!"
        mock_collection.find_one.return_value = None
        mock_collection.insert_one.return_value = MagicMock()

        # Test with email containing whitespace
        request_data = AdminRegisterRequest(
            email="  ADMIN@EXAMPLE.COM  ",  # Whitespace + uppercase
            keyID="Westfield Sydney",
        )

        result = register_admin(request_data)

        assert result["msg"] == "Admin registered successfully"

        # Verify email was trimmed and normalized
        # Check that at least one call was made with the normalized email
        calls = mock_collection.find_one.call_args_list
        email_calls = [
            call for call in calls if call[0][0].get("email") == "admin@example.com"
        ]
        assert len(email_calls) >= 1

        # Verify normalized email in database insert
        insert_call_args = mock_collection.insert_one.call_args[0][0]
        assert insert_call_args["email"] == "admin@example.com"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.generate_username")
    @patch("app.admin.router.generate_password")
    def test_admin_register_username_collision_handling(
        self, mock_generate_password, mock_generate_username, mock_collection
    ):
        """Test handling of username collisions during generation"""
        mock_generate_password.return_value = "TempPass123!"
        mock_collection.insert_one.return_value = MagicMock()

        # Mock username generation to simulate collision
        mock_generate_username.side_effect = [
            "abcd1234",
            "efgh5678",
        ]  # First is taken, second is free

        def mock_find_one(query):
            if "email" in query:
                return None  # Email not registered
            elif "username" in query and query["username"] == "abcd1234":
                return {"username": "abcd1234"}  # First username taken
            elif "username" in query and query["username"] == "efgh5678":
                return None  # Second username free
            return None

        mock_collection.find_one.side_effect = mock_find_one

        request_data = AdminRegisterRequest(
            email="admin@example.com", keyID="Westfield Sydney"
        )

        result = register_admin(request_data)

        assert result["msg"] == "Admin registered successfully"
        assert (
            result["username"] == "efgh5678"
        )  # Should use the second generated username

        # Verify username generation was called twice
        assert mock_generate_username.call_count == 2

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.generate_username")
    @patch("app.admin.router.generate_password")
    def test_admin_register_special_characters_in_keyid(
        self, mock_generate_password, mock_generate_username, mock_collection
    ):
        """Test admin registration with special characters in keyID"""
        mock_generate_username.return_value = "abcd1234"
        mock_generate_password.return_value = "TempPass123!"
        mock_collection.find_one.return_value = None
        mock_collection.insert_one.return_value = MagicMock()

        request_data = AdminRegisterRequest(
            email="admin@example.com",
            keyID="Westfield Sydney - Level 1 & 2",  # Special characters
        )

        result = register_admin(request_data)

        assert result["msg"] == "Admin registered successfully"

        # Verify keyID is stored as-is
        insert_call_args = mock_collection.insert_one.call_args[0][0]
        assert insert_call_args["keyID"] == "Westfield Sydney - Level 1 & 2"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.generate_username")
    @patch("app.admin.router.generate_password")
    @patch("app.admin.router.metrics")
    def test_admin_register_metrics_recording(
        self,
        mock_metrics,
        mock_generate_password,
        mock_generate_username,
        mock_collection,
    ):
        """Test that admin registration records metrics correctly"""
        mock_generate_username.return_value = "abcd1234"
        mock_generate_password.return_value = "TempPass123!"
        mock_collection.find_one.return_value = None
        mock_collection.insert_one.return_value = MagicMock()

        request_data = AdminRegisterRequest(
            email="admin@example.com", keyID="Westfield Sydney"
        )

        result = register_admin(request_data)

        assert result["msg"] == "Admin registered successfully"

        # Verify metrics were recorded
        mock_metrics.record_auth_event.assert_called_once_with("admin_register", True)
        mock_metrics.increment_counter.assert_called_once_with(
            "AdminOperations", {"operation": "register"}
        )

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.metrics")
    def test_admin_register_failure_metrics_recording(
        self, mock_metrics, mock_collection
    ):
        """Test that admin registration failure records metrics correctly"""
        mock_collection.find_one.return_value = {
            "email": "admin@example.com"
        }  # Email already registered

        request_data = AdminRegisterRequest(
            email="admin@example.com", keyID="Westfield Sydney"
        )

        with pytest.raises(HTTPException):
            register_admin(request_data)

        # Verify failure metrics were recorded
        mock_metrics.record_auth_event.assert_called_once_with("admin_register", False)

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.generate_username")
    @patch("app.admin.router.generate_password")
    def test_admin_register_empty_keyid(
        self, mock_generate_password, mock_generate_username, mock_collection
    ):
        """Test admin registration with empty keyID (should still work as keyID is just a string field)"""
        mock_generate_username.return_value = "abcd1234"
        mock_generate_password.return_value = "TempPass123!"
        mock_collection.find_one.return_value = None
        mock_collection.insert_one.return_value = MagicMock()

        request_data = AdminRegisterRequest(
            email="admin@example.com", keyID=""  # Empty keyID
        )

        result = register_admin(request_data)

        assert result["msg"] == "Admin registered successfully"

        # Verify empty keyID is stored
        insert_call_args = mock_collection.insert_one.call_args[0][0]
        assert insert_call_args["keyID"] == ""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.generate_username")
    @patch("app.admin.router.generate_password")
    def test_admin_register_very_long_keyid(
        self, mock_generate_password, mock_generate_username, mock_collection
    ):
        """Test admin registration with very long keyID"""
        mock_generate_username.return_value = "abcd1234"
        mock_generate_password.return_value = "TempPass123!"
        mock_collection.find_one.return_value = None
        mock_collection.insert_one.return_value = MagicMock()

        long_keyid = "A" * 1000  # Very long keyID
        request_data = AdminRegisterRequest(email="admin@example.com", keyID=long_keyid)

        result = register_admin(request_data)

        assert result["msg"] == "Admin registered successfully"

        # Verify long keyID is stored
        insert_call_args = mock_collection.insert_one.call_args[0][0]
        assert insert_call_args["keyID"] == long_keyid
        assert len(insert_call_args["keyID"]) == 1000


class TestAdminUsernameGeneration:
    """Test cases for admin username generation utility"""

    @patch("app.admin.router.random.choices")
    def test_generate_username_format(self, mock_choices):
        """Test that generate_username produces correct format"""
        # Mock random choices for predictable output
        mock_choices.side_effect = [
            ["a", "b", "c", "d"],  # letters
            ["1", "2", "3", "4"],  # digits
        ]

        from app.admin.router import generate_username

        result = generate_username()

        assert result == "abcd1234"
        assert len(result) == 8
        assert result[:4].islower()  # First 4 are lowercase letters
        assert result[4:].isdigit()  # Last 4 are digits

    def test_generate_username_randomness(self):
        """Test that generate_username produces different results"""
        from app.admin.router import generate_username

        usernames = set()
        for _ in range(100):
            username = generate_username()
            assert len(username) == 8
            assert username[:4].islower()
            assert username[4:].isdigit()
            usernames.add(username)

        # Should generate many different usernames
        assert len(usernames) > 50  # Expect good randomness


class TestAdminPasswordGeneration:
    """Test cases for admin password generation utility"""

    def test_generate_password_default_length(self):
        """Test generate_password with default length"""
        from app.admin.router import generate_password

        password = generate_password()

        assert len(password) == 10  # Default length
        assert any(c.isupper() for c in password)  # Has uppercase
        assert any(c.islower() for c in password)  # Has lowercase
        assert any(c.isdigit() for c in password)  # Has digit
        assert any(c in string.punctuation for c in password)  # Has special char

    def test_generate_password_custom_length(self):
        """Test generate_password with custom length"""
        from app.admin.router import generate_password

        for length in [8, 12, 16, 20]:
            password = generate_password(length)
            assert len(password) == length
            assert any(c.isupper() for c in password)
            assert any(c.islower() for c in password)
            assert any(c.isdigit() for c in password)
            assert any(c in string.punctuation for c in password)

    def test_generate_password_minimum_length_error(self):
        """Test generate_password with length less than 4"""
        from app.admin.router import generate_password

        with pytest.raises(ValueError) as exc_info:
            generate_password(3)

        assert "Password length must be at least 4" in str(exc_info.value)

    def test_generate_password_uniqueness(self):
        """Test that generate_password produces different results"""
        from app.admin.router import generate_password

        passwords = set()
        for _ in range(50):
            password = generate_password()
            passwords.add(password)

        # Should generate many different passwords
        assert len(passwords) > 40  # Expect good randomness
