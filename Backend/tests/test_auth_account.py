import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from app.auth.router import delete_account, edit_profile, get_profile
from app.auth.auth import DeleteAccountRequest, UserEdit

# Delete profile, Edit profile, Get profile
# APIs:
# /auth/delete-account
# /auth/edit-profile
# /auth/get-profile


class TestDeleteAccount:
    """Test cases for delete account functionality"""

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    def test_delete_account_success(self, mock_verify, mock_collection):
        """Test successful account deletion"""
        mock_verify.return_value = True

        user_doc = {"email": "test@example.com", "password": "hashed_password"}
        mock_collection.find_one.return_value = user_doc
        mock_collection.delete_one.return_value = MagicMock()

        delete_data = DeleteAccountRequest(
            email="test@example.com", password="TestPass123!"
        )

        result = delete_account(delete_data)

        assert result["msg"] == "Account deleted successfully."
        mock_collection.delete_one.assert_called_once_with(
            {"email": "test@example.com"}
        )

    @patch("app.auth.router.user_collection")
    def test_delete_account_user_not_found(self, mock_collection):
        """Test account deletion with non-existent user"""
        mock_collection.find_one.return_value = None

        delete_data = DeleteAccountRequest(
            email="nonexistent@example.com", password="TestPass123!"
        )

        with pytest.raises(HTTPException) as exc_info:
            delete_account(delete_data)

        assert exc_info.value.status_code == 404
        assert exc_info.value.detail == "User not found."

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    def test_delete_account_incorrect_password(self, mock_verify, mock_collection):
        """Test account deletion with incorrect password"""
        mock_verify.return_value = False

        user_doc = {"email": "test@example.com", "password": "hashed_password"}
        mock_collection.find_one.return_value = user_doc

        delete_data = DeleteAccountRequest(
            email="test@example.com", password="WrongPassword123!"
        )

        with pytest.raises(HTTPException) as exc_info:
            delete_account(delete_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Password is incorrect."

    @patch("app.auth.router.user_collection")
    @patch("app.auth.router.verify_password")
    def test_delete_account_email_case_insensitive(self, mock_verify, mock_collection):
        """Test that email is handled case-insensitively in account deletion"""
        mock_verify.return_value = True

        user_doc = {"email": "test@example.com", "password": "hashed_password"}
        mock_collection.find_one.return_value = user_doc
        mock_collection.delete_one.return_value = MagicMock()

        delete_data = DeleteAccountRequest(
            email="TEST@EXAMPLE.COM", password="TestPass123!"  # Uppercase
        )

        result = delete_account(delete_data)

        assert result["msg"] == "Account deleted successfully."
        # Verify email was converted to lowercase
        mock_collection.find_one.assert_called_with({"email": "test@example.com"})
        mock_collection.delete_one.assert_called_with({"email": "test@example.com"})


class TestEditProfile:
    """Test cases for edit profile functionality"""

    @patch("app.auth.router.user_collection")
    def test_edit_profile_success_all_fields(self, mock_collection):
        """Test successful profile edit with all fields"""
        user_doc = {
            "email": "test@example.com",
            "username": "oldusername",
            "fullname": "Old Name",
        }

        # Set up mock to return user_doc for first call, None for username check
        def side_effect(query):
            if "email" in query and query.get("email") == "test@example.com":
                return user_doc  # User exists
            elif "username" in query:
                return None  # Username not taken by another user
            return None

        mock_collection.find_one.side_effect = side_effect
        mock_collection.update_one.return_value = MagicMock()

        edit_data = UserEdit(
            email="test@example.com",
            fullname="New Full Name",
            username="newusername",
            license_plate="ABC123",
            phone_number="1234567890",
            address="123 New Street",
        )

        result = edit_profile(edit_data)

        assert result["msg"] == "Profile updated successfully."

        expected_update = {
            "fullname": "New Full Name",
            "username": "newusername",
            "license_plate": "ABC123",
            "phone_number": "1234567890",
            "address": "123 New Street",
        }
        mock_collection.update_one.assert_called_once_with(
            {"email": "test@example.com"}, {"$set": expected_update}
        )

    @patch("app.auth.router.user_collection")
    def test_edit_profile_success_single_field(self, mock_collection):
        """Test successful profile edit with single field"""
        user_doc = {
            "email": "test@example.com",
            "username": "testuser",
            "fullname": "Old Name",
        }
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        edit_data = UserEdit(
            email="test@example.com",
            fullname="New Full Name",
            # Other fields are None
        )

        result = edit_profile(edit_data)

        assert result["msg"] == "Profile updated successfully."

        expected_update = {"fullname": "New Full Name"}
        mock_collection.update_one.assert_called_once_with(
            {"email": "test@example.com"}, {"$set": expected_update}
        )

    @patch("app.auth.router.user_collection")
    def test_edit_profile_user_not_found(self, mock_collection):
        """Test profile edit with non-existent user"""
        mock_collection.find_one.return_value = None

        edit_data = UserEdit(email="nonexistent@example.com", fullname="New Name")

        with pytest.raises(HTTPException) as exc_info:
            edit_profile(edit_data)

        assert exc_info.value.status_code == 404
        assert exc_info.value.detail == "User not found."

    @patch("app.auth.router.user_collection")
    def test_edit_profile_username_taken(self, mock_collection):
        """Test profile edit with username already taken"""

        def side_effect(query):
            if query == {"email": "test@example.com"}:
                return {"email": "test@example.com", "username": "oldusername"}
            elif query == {
                "username": "takenusername",
                "email": {"$ne": "test@example.com"},
            }:
                return {"username": "takenusername", "email": "other@example.com"}
            return None

        mock_collection.find_one.side_effect = side_effect

        edit_data = UserEdit(email="test@example.com", username="takenusername")

        with pytest.raises(HTTPException) as exc_info:
            edit_profile(edit_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Username already taken."

    @patch("app.auth.router.user_collection")
    def test_edit_profile_username_same_user(self, mock_collection):
        """Test profile edit with username belonging to same user (should succeed)"""

        def side_effect(query):
            if query == {"email": "test@example.com"}:
                return {"email": "test@example.com", "username": "currentusername"}
            elif query == {
                "username": "currentusername",
                "email": {"$ne": "test@example.com"},
            }:
                return None  # Username have not been taken
            return None

        mock_collection.find_one.side_effect = side_effect
        mock_collection.update_one.return_value = MagicMock()

        edit_data = UserEdit(
            email="test@example.com",
            username="currentusername",  # Same as curr username
        )

        result = edit_profile(edit_data)

        assert result["msg"] == "Profile updated successfully."

    @patch("app.auth.router.user_collection")
    def test_edit_profile_no_fields_to_update(self, mock_collection):
        """Test profile edit with no fields to update"""
        user_doc = {"email": "test@example.com", "username": "testuser"}
        mock_collection.find_one.return_value = user_doc

        edit_data = UserEdit(
            email="test@example.com"
            # All optional fields are None
        )

        with pytest.raises(HTTPException) as exc_info:
            edit_profile(edit_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "No fields to update."

    @patch("app.auth.router.user_collection")
    def test_edit_profile_email_case_insensitive(self, mock_collection):
        """Test that email is handled case-insensitively in profile edit"""
        user_doc = {"email": "test@example.com", "username": "testuser"}
        mock_collection.find_one.return_value = user_doc
        mock_collection.update_one.return_value = MagicMock()

        edit_data = UserEdit(email="TEST@EXAMPLE.COM", fullname="New Name")  # Uppercase

        result = edit_profile(edit_data)

        assert result["msg"] == "Profile updated successfully."
        # Verify email was converted to lowercase
        mock_collection.find_one.assert_called_with({"email": "test@example.com"})


class TestGetProfile:
    """Test cases for get profile functionality"""

    @patch("app.auth.router.user_collection")
    def test_get_profile_success(self, mock_collection):
        """Test successful profile retrieval"""
        user_doc = {
            "email": "test@example.com",
            "username": "testuser",
            "fullname": "Test User",
            "license_plate": "ABC123",
            "phone_number": "1234567890",
            "address": "123 Test Street",
            "vehicle": None,
            "failed_login_attempts": 0,
            "suspend_until": 0,
            "role": "user",
        }
        mock_collection.find_one.return_value = user_doc

        result = get_profile("test@example.com")

        assert result == user_doc
        mock_collection.find_one.assert_called_once_with(
            {"email": "test@example.com"}, {"_id": 0, "password": 0}
        )

    @patch("app.auth.router.user_collection")
    def test_get_profile_user_not_found(self, mock_collection):
        """Test profile retrieval with non-existent user"""
        mock_collection.find_one.return_value = None

        with pytest.raises(HTTPException) as exc_info:
            get_profile("nonexistent@example.com")

        assert exc_info.value.status_code == 404
        assert exc_info.value.detail == "User not found"

    @patch("app.auth.router.user_collection")
    def test_get_profile_email_case_insensitive(self, mock_collection):
        """Test that email is handled case-insensitively in profile retrieval"""
        user_doc = {
            "email": "test@example.com",
            "username": "testuser",
            "fullname": "Test User",
        }
        mock_collection.find_one.return_value = user_doc

        result = get_profile("TEST@EXAMPLE.COM")  # Uppercase

        assert result == user_doc
        # Verify email was converted to lowercase
        mock_collection.find_one.assert_called_once_with(
            {"email": "test@example.com"}, {"_id": 0, "password": 0}
        )

    @patch("app.auth.router.user_collection")
    def test_get_profile_excludes_sensitive_data(self, mock_collection):
        """Test that profile retrieval excludes sensitive data"""
        user_doc = {
            "email": "test@example.com",
            "username": "testuser",
            "fullname": "Test User",
            # Note: _id and password should be excluded by the projection
        }
        mock_collection.find_one.return_value = user_doc

        result = get_profile("test@example.com")

        assert result == user_doc
        # Verify projection excludes _id and password
        mock_collection.find_one.assert_called_once_with(
            {"email": "test@example.com"}, {"_id": 0, "password": 0}
        )

    @patch("app.auth.router.user_collection")
    def test_get_profile_with_email_whitespace(self, mock_collection):
        """Test profile retrieval with email containing whitespace"""
        user_doc = {
            "email": "test@example.com",
            "username": "testuser",
            "fullname": "Test User",
        }
        mock_collection.find_one.return_value = user_doc

        result = get_profile("  test@example.com  ")  # With whitespace

        assert result == user_doc
        # check email was trimmed and converted to lowercase
        mock_collection.find_one.assert_called_once_with(
            {"email": "test@example.com"}, {"_id": 0, "password": 0}
        )
