import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from app.admin.router import admin_edit_profile, admin_change_password
from app.auth.auth import AdminEdit, AdminChangePassword
from app.auth.utils import hash_password

# test cases for admin profile management
# APIs:
# /admin/admin_edit_profile
# /admin/admin_change_password


class TestAdminEditProfile:
    """Test cases for admin profile editing functionality"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_edit_profile_success(self, mock_verify, mock_collection):
        """Test successful admin profile edit"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "olduser",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }

        def mock_find_one(query):
            if "keyID" in query:
                return admin_doc
            elif "username" in query and query["username"] == "newuser":
                return None  # New username is not taken
            return None

        mock_collection.find_one.side_effect = mock_find_one
        mock_collection.update_one.return_value = MagicMock()

        edit_data = AdminEdit(
            keyID="westfield sydney",  # Case insensitive
            current_username="olduser",
            current_password="TestPass123!",
            new_username="newuser",
        )

        result = admin_edit_profile(edit_data)

        assert result["success"] is True
        assert result["message"] == "Profile updated successfully"
        assert result["admin_info"]["username"] == "newuser"
        assert result["admin_info"]["keyID"] == "Westfield Sydney"
        assert result["admin_info"]["email"] == "admin@example.com"
        assert "username=newuser" in result["changes_summary"]["changed_fields"]

        # Verify database update
        mock_collection.update_one.assert_called_once_with(
            {"keyID": "Westfield Sydney"}, {"$set": {"username": "newuser"}}
        )

    @patch("app.admin.router.user_collection")
    def test_admin_edit_profile_invalid_keyid(self, mock_collection):
        """Test admin profile edit with invalid keyID"""
        mock_collection.find_one.return_value = None

        edit_data = AdminEdit(
            keyID="Invalid KeyID",
            current_username="admin123",
            current_password="TestPass123!",
            new_username="newuser",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_profile(edit_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Invalid keyID and username combination"

    @patch("app.admin.router.user_collection")
    def test_admin_edit_profile_username_mismatch(self, mock_collection):
        """Test admin profile edit with wrong username for keyID (new logic returns no match)"""
        # With new authentication logic, wrong username for keyID returns None from database
        mock_collection.find_one.return_value = (
            None  # No admin found with this keyID+username combo
        )

        edit_data = AdminEdit(
            keyID="Westfield Sydney",
            current_username="wronguser",  # Wrong username for this keyID
            current_password="TestPass123!",
            new_username="newuser",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_profile(edit_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Invalid keyID and username combination"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_edit_profile_incorrect_password(self, mock_verify, mock_collection):
        """Test admin profile edit with incorrect password"""
        mock_verify.return_value = False

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        edit_data = AdminEdit(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="WrongPassword!",
            new_username="newuser",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_profile(edit_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Incorrect password"

    @patch("app.admin.router.user_collection")
    def test_admin_edit_profile_plain_password_verification(self, mock_collection):
        """Test admin profile edit with plain text password verification"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "TestPass123!",  # Plain text password
            "keyID": "Westfield Sydney",
            "role": "admin",
        }

        def mock_find_one(query):
            if "keyID" in query:
                return admin_doc
            elif "username" in query and query["username"] == "newuser":
                return None  # New username is not taken
            return None

        mock_collection.find_one.side_effect = mock_find_one
        mock_collection.update_one.return_value = MagicMock()

        edit_data = AdminEdit(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="TestPass123!",
            new_username="newuser",
        )

        result = admin_edit_profile(edit_data)

        assert result["success"] is True
        assert result["message"] == "Profile updated successfully"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_edit_profile_non_admin_role(self, mock_verify, mock_collection):
        """Test admin profile edit with non-admin role"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "user",  # Not admin
        }
        mock_collection.find_one.return_value = admin_doc

        edit_data = AdminEdit(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="TestPass123!",
            new_username="newuser",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_profile(edit_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Access denied. Admin role required."

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_edit_profile_empty_username(self, mock_verify, mock_collection):
        """Test admin profile edit with empty new username"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        edit_data = AdminEdit(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="TestPass123!",
            new_username="   ",  # Empty username
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_profile(edit_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Username cannot be empty."

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_edit_profile_same_username(self, mock_verify, mock_collection):
        """Test admin profile edit with same username (no changes)"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        edit_data = AdminEdit(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="TestPass123!",
            new_username="admin123",  # Same username
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_profile(edit_data)

        assert exc_info.value.status_code == 400
        assert (
            exc_info.value.detail
            == "New username is the same as current username. No changes made."
        )

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_edit_profile_username_taken(self, mock_verify, mock_collection):
        """Test admin profile edit with username already taken by another admin"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }

        def mock_find_one(query):
            if "keyID" in query:
                return admin_doc
            elif "username" in query and query["username"] == "takenuser":
                return {
                    "username": "takenuser",
                    "keyID": "Different KeyID",
                    "role": "admin",
                }
            return None

        mock_collection.find_one.side_effect = mock_find_one

        edit_data = AdminEdit(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="TestPass123!",
            new_username="takenuser",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_profile(edit_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Username already taken by another admin."

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.metrics")
    def test_admin_edit_profile_metrics_recording(
        self, mock_metrics, mock_verify, mock_collection
    ):
        """Test that admin profile edit records metrics correctly"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }

        def mock_find_one(query):
            if "keyID" in query:
                return admin_doc
            elif "username" in query and query["username"] == "newuser":
                return None  # New username is not taken
            return None

        mock_collection.find_one.side_effect = mock_find_one
        mock_collection.update_one.return_value = MagicMock()

        edit_data = AdminEdit(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="TestPass123!",
            new_username="newuser",
        )

        result = admin_edit_profile(edit_data)

        assert result["success"] is True

        # Verify metrics were recorded
        mock_metrics.record_auth_event.assert_called_once_with(
            "admin_edit_profile", True
        )
        mock_metrics.increment_counter.assert_called_once_with(
            "AdminOperations", {"operation": "edit_profile"}
        )


class TestAdminChangePassword:
    """Test cases for admin password change functionality"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.hash_password")
    def test_admin_change_password_success(
        self, mock_hash, mock_verify, mock_collection
    ):
        """Test successful admin password change"""
        mock_verify.return_value = True
        mock_hash.return_value = "new_hashed_password"

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$old_hashed_password",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc
        mock_collection.update_one.return_value = MagicMock()

        change_data = AdminChangePassword(
            keyID="westfield sydney",  # Case insensitive
            current_username="admin123",
            current_password="OldPass123!",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        result = admin_change_password(change_data)

        assert result["msg"] == "Password changed successfully."

        # Verify password was hashed and updated
        mock_hash.assert_called_once_with("NewPass456@")
        mock_collection.update_one.assert_called_once_with(
            {"keyID": "Westfield Sydney"}, {"$set": {"password": "new_hashed_password"}}
        )

    @patch("app.admin.router.user_collection")
    def test_admin_change_password_invalid_keyid(self, mock_collection):
        """Test admin password change with invalid keyID"""
        mock_collection.find_one.return_value = None

        change_data = AdminChangePassword(
            keyID="Invalid KeyID",
            current_username="admin123",
            current_password="OldPass123!",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_change_password(change_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Invalid keyID and username combination"

    @patch("app.admin.router.user_collection")
    def test_admin_change_password_username_mismatch(self, mock_collection):
        """Test admin password change with wrong username for keyID (new logic returns no match)"""
        # With new authentication logic, wrong username for keyID returns None from database
        mock_collection.find_one.return_value = (
            None  # No admin found with this keyID+username combo
        )

        change_data = AdminChangePassword(
            keyID="Westfield Sydney",
            current_username="wronguser",  # Wrong username for this keyID
            current_password="OldPass123!",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_change_password(change_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Invalid keyID and username combination"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_change_password_incorrect_current_password(
        self, mock_verify, mock_collection
    ):
        """Test admin password change with incorrect current password"""
        mock_verify.return_value = False

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashed_password",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        change_data = AdminChangePassword(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="WrongPassword!",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_change_password(change_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Current password is incorrect."

    @patch("app.admin.router.user_collection")
    def test_admin_change_password_plain_text_verification(self, mock_collection):
        """Test admin password change with plain text password verification"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "OldPass123!",  # Plain text password
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        change_data = AdminChangePassword(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="WrongPassword!",  # Wrong password
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_change_password(change_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Current password is incorrect."

    @patch("app.admin.router.user_collection")
    def test_admin_change_password_mismatch(self, mock_collection):
        """Test admin password change with password mismatch"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "OldPass123!",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        change_data = AdminChangePassword(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="OldPass123!",
            new_password="NewPass456@",
            confirm_new_password="DifferentPass789#",  # Mismatch
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_change_password(change_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "New password and confirmation do not match."

    @patch("app.admin.router.user_collection")
    def test_admin_change_password_same_as_current(self, mock_collection):
        """Test admin password change with same password as current"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "TestPass123!",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        change_data = AdminChangePassword(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="TestPass123!",
            new_password="TestPass123!",  # Same as current
            confirm_new_password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_change_password(change_data)

        assert exc_info.value.status_code == 400
        assert (
            exc_info.value.detail
            == "New password cannot be the same as the current password."
        )

    @patch("app.admin.router.user_collection")
    def test_admin_change_password_validation_too_short(self, mock_collection):
        """Test admin password change with password too short"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "OldPass123!",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        change_data = AdminChangePassword(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="OldPass123!",
            new_password="Short1!",  # Too short
            confirm_new_password="Short1!",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_change_password(change_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Password must be at least 8 characters long"

    @patch("app.admin.router.user_collection")
    def test_admin_change_password_validation_no_number(self, mock_collection):
        """Test admin password change with password missing number"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "OldPass123!",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        change_data = AdminChangePassword(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="OldPass123!",
            new_password="NewPassword!",  # No number
            confirm_new_password="NewPassword!",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_change_password(change_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Password must contain at least one number"

    @patch("app.admin.router.user_collection")
    def test_admin_change_password_validation_no_special_char(self, mock_collection):
        """Test admin password change with password missing special character"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "OldPass123!",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        change_data = AdminChangePassword(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="OldPass123!",
            new_password="NewPassword123",  # No special character
            confirm_new_password="NewPassword123",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_change_password(change_data)

        assert exc_info.value.status_code == 400
        assert (
            exc_info.value.detail
            == "Password must contain at least one special character"
        )

    @patch("app.admin.router.user_collection")
    def test_admin_change_password_validation_common_password(self, mock_collection):
        """Test admin password change with common password"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "OldPass123!",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        change_data = AdminChangePassword(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="OldPass123!",
            new_password="password123!",  # Common password
            confirm_new_password="password123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_change_password(change_data)

        assert exc_info.value.status_code == 400
        assert (
            exc_info.value.detail
            == "Password is too common. Please choose a more secure one."
        )

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_change_password_non_admin_role(self, mock_verify, mock_collection):
        """Test admin password change with non-admin role"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashed_password",
            "keyID": "Westfield Sydney",
            "role": "user",  # Not admin
        }
        mock_collection.find_one.return_value = admin_doc

        change_data = AdminChangePassword(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="OldPass123!",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_change_password(change_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Access denied. Admin role required."

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.hash_password")
    @patch("app.admin.router.metrics")
    def test_admin_change_password_metrics_recording(
        self, mock_metrics, mock_hash, mock_verify, mock_collection
    ):
        """Test that admin password change records metrics correctly"""
        mock_verify.return_value = True
        mock_hash.return_value = "new_hashed_password"

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$old_hashed_password",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc
        mock_collection.update_one.return_value = MagicMock()

        change_data = AdminChangePassword(
            keyID="Westfield Sydney",
            current_username="admin123",
            current_password="OldPass123!",
            new_password="NewPass456@",
            confirm_new_password="NewPass456@",
        )

        result = admin_change_password(change_data)

        assert result["msg"] == "Password changed successfully."

        # Verify metrics were recorded
        mock_metrics.record_auth_event.assert_called_once_with(
            "admin_change_password", True
        )
        mock_metrics.increment_counter.assert_called_once_with(
            "AdminOperations", {"operation": "change_password"}
        )
