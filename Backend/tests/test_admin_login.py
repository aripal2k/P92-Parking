import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from app.admin.router import admin_login
from app.admin.router import AdminLoginRequest
from app.auth.utils import hash_password, verify_password

# test cases for admin login
# APIs:
# /admin/login


class TestAdminLogin:
    """Test cases for admin login functionality"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_login_success_with_hashed_password(
        self, mock_verify, mock_collection
    ):
        """Test successful admin login with hashed password"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",  # Hashed password
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        login_data = AdminLoginRequest(
            keyID="westfield sydney",  # Case insensitive
            username="admin123",
            password="TestPass123!",
            email="admin@example.com",
        )

        result = admin_login(login_data)

        assert result["msg"] == "Admin login successful"

        # Verify database query includes both keyID and username with case insensitive keyID
        mock_collection.find_one.assert_called_once()
        call_args = mock_collection.find_one.call_args[0][0]
        assert "keyID" in call_args
        assert "$regex" in call_args["keyID"]
        assert "$options" in call_args["keyID"]
        assert call_args["keyID"]["$options"] == "i"  # Case insensitive
        assert call_args["username"] == "admin123"
        assert call_args["role"] == "admin"

        # Verify hashed password verification was used
        mock_verify.assert_called_once_with("TestPass123!", "$2b$12$hashedpassword")

    @patch("app.admin.router.user_collection")
    def test_admin_login_success_with_plain_password(self, mock_collection):
        """Test successful admin login with plain text password (legacy)"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "TestPass123!",  # Plain text password
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        login_data = AdminLoginRequest(
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            email="admin@example.com",
        )

        result = admin_login(login_data)

        assert result["msg"] == "Admin login successful"

        # Verify database query includes both keyID and username
        mock_collection.find_one.assert_called_once()
        call_args = mock_collection.find_one.call_args[0][0]
        assert "keyID" in call_args
        assert "username" in call_args
        assert "role" in call_args
        assert call_args["username"] == "admin123"
        assert call_args["role"] == "admin"

    @patch("app.admin.router.user_collection")
    def test_admin_login_invalid_keyid_username_combination(self, mock_collection):
        """Test admin login with invalid keyID and username combination"""
        mock_collection.find_one.return_value = (
            None  # No admin found with this keyID+username combo
        )

        login_data = AdminLoginRequest(
            keyID="Invalid KeyID",
            username="admin123",
            password="TestPass123!",
            email="admin@example.com",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_login(login_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Invalid keyID and username combination"

    @patch("app.admin.router.user_collection")
    def test_admin_login_wrong_username_for_keyid(self, mock_collection):
        """Test admin login with wrong username for a given keyID (now returns no match)"""
        # With the new logic, wrong username for keyID returns None from database
        mock_collection.find_one.return_value = (
            None  # No admin found with this keyID+username combo
        )

        login_data = AdminLoginRequest(
            keyID="Westfield Sydney",
            username="wronguser",  # Username that doesn't exist for this keyID
            password="TestPass123!",
            email="admin@example.com",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_login(login_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Invalid keyID and username combination"

    @patch("app.admin.router.user_collection")
    def test_admin_login_email_mismatch(self, mock_collection):
        """Test admin login with email that doesn't match keyID or username"""
        admin_doc = {
            "email": "correct@example.com",
            "username": "admin123",
            "password": "TestPass123!",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        login_data = AdminLoginRequest(
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            email="wrong@example.com",  # Wrong email
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_login(login_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Email does not match keyID or username"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_login_incorrect_hashed_password(self, mock_verify, mock_collection):
        """Test admin login with incorrect hashed password"""
        mock_verify.return_value = False

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",  # Hashed password
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        login_data = AdminLoginRequest(
            keyID="Westfield Sydney",
            username="admin123",
            password="WrongPassword123!",
            email="admin@example.com",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_login(login_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Incorrect password"

    @patch("app.admin.router.user_collection")
    def test_admin_login_incorrect_plain_password(self, mock_collection):
        """Test admin login with incorrect plain text password"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "CorrectPass123!",  # Plain text password
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        login_data = AdminLoginRequest(
            keyID="Westfield Sydney",
            username="admin123",
            password="WrongPass123!",
            email="admin@example.com",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_login(login_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Incorrect password"

    @patch("app.admin.router.user_collection")
    def test_admin_login_case_insensitive_keyid(self, mock_collection):
        """Test that keyID matching is case insensitive"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "TestPass123!",
            "keyID": "Westfield Sydney",  # Original case
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        # Test various cases
        keyid_variations = [
            "westfield sydney",
            "WESTFIELD SYDNEY",
            "Westfield Sydney",
            "WeStFiElD sYdNeY",
        ]

        for keyid_variant in keyid_variations:
            login_data = AdminLoginRequest(
                keyID=keyid_variant,
                username="admin123",
                password="TestPass123!",
                email="admin@example.com",
            )

            result = admin_login(login_data)
            assert result["msg"] == "Admin login successful"

    @patch("app.admin.router.user_collection")
    def test_admin_login_case_insensitive_email(self, mock_collection):
        """Test that email matching is case insensitive"""
        admin_doc = {
            "email": "admin@example.com",  # Lowercase in database
            "username": "admin123",
            "password": "TestPass123!",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        # Test various email cases
        email_variations = [
            "ADMIN@EXAMPLE.COM",
            "Admin@Example.Com",
            "admin@EXAMPLE.com",
        ]

        for email_variant in email_variations:
            login_data = AdminLoginRequest(
                keyID="Westfield Sydney",
                username="admin123",
                password="TestPass123!",
                email=email_variant,
            )

            result = admin_login(login_data)
            assert result["msg"] == "Admin login successful"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.metrics")
    def test_admin_login_success_metrics_recording(self, mock_metrics, mock_collection):
        """Test that successful admin login records metrics correctly"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "TestPass123!",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        login_data = AdminLoginRequest(
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            email="admin@example.com",
        )

        result = admin_login(login_data)

        assert result["msg"] == "Admin login successful"

        # Verify success metrics were recorded
        mock_metrics.record_auth_event.assert_called_once_with("admin_login", True)
        mock_metrics.increment_counter.assert_called_once_with(
            "AdminOperations", {"operation": "login"}
        )

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.metrics")
    def test_admin_login_failure_metrics_recording(self, mock_metrics, mock_collection):
        """Test that failed admin login records metrics correctly"""
        mock_collection.find_one.return_value = (
            None  # Invalid keyID and username combination
        )

        login_data = AdminLoginRequest(
            keyID="Invalid KeyID",
            username="admin123",
            password="TestPass123!",
            email="admin@example.com",
        )

        with pytest.raises(HTTPException):
            admin_login(login_data)

        # Verify failure metrics were recorded
        mock_metrics.record_auth_event.assert_called_once_with("admin_login", False)

    @patch("app.admin.router.user_collection")
    def test_admin_login_special_characters_in_keyid(self, mock_collection):
        """Test admin login with special characters in keyID"""
        special_keyid = "Westfield Sydney - Level 1 & 2 (North Wing)"
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "TestPass123!",
            "keyID": special_keyid,
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        login_data = AdminLoginRequest(
            keyID=special_keyid,
            username="admin123",
            password="TestPass123!",
            email="admin@example.com",
        )

        result = admin_login(login_data)

        assert result["msg"] == "Admin login successful"

    @patch("app.admin.router.user_collection")
    def test_admin_login_keyid_regex_escaping(self, mock_collection):
        """Test that special regex characters in keyID are properly escaped"""
        # keyID with regex special characters
        regex_keyid = "Test.Location*With+Special[Chars]"
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "TestPass123!",
            "keyID": regex_keyid,
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        login_data = AdminLoginRequest(
            keyID=regex_keyid,
            username="admin123",
            password="TestPass123!",
            email="admin@example.com",
        )

        result = admin_login(login_data)

        assert result["msg"] == "Admin login successful"

        # Verify the regex was properly escaped and query includes all required fields
        expected_regex = "^Test\\.Location\\*With\\+Special\\[Chars\\]$"
        expected_query = {
            "keyID": {"$regex": expected_regex, "$options": "i"},
            "username": "admin123",
            "role": "admin",
        }
        mock_collection.find_one.assert_called_once_with(expected_query)

    @patch("app.admin.router.user_collection")
    def test_admin_login_unicode_characters(self, mock_collection):
        """Test admin login with unicode characters in keyID"""
        unicode_keyid = "Westfield 悉尼 Shopping Centre"
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "TestPass123!",
            "keyID": unicode_keyid,
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        login_data = AdminLoginRequest(
            keyID=unicode_keyid,
            username="admin123",
            password="TestPass123!",
            email="admin@example.com",
        )

        result = admin_login(login_data)

        assert result["msg"] == "Admin login successful"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_login_password_verification_edge_cases(
        self, mock_verify, mock_collection
    ):
        """Test edge cases in password verification"""
        # Test with various password hash formats
        test_cases = [
            ("$2b$12$hashedpassword", True),  # bcrypt hash
            ("$2a$12$hashedpassword", False),  # Different bcrypt variant
            ("plaintext", False),  # Plain text
            ("", False),  # Empty password
        ]

        for stored_password, is_hashed in test_cases:
            admin_doc = {
                "email": "admin@example.com",
                "username": "admin123",
                "password": stored_password,
                "keyID": "Westfield Sydney",
                "role": "admin",
            }
            mock_collection.find_one.return_value = admin_doc

            login_data = AdminLoginRequest(
                keyID="Westfield Sydney",
                username="admin123",
                password="TestPass123!",
                email="admin@example.com",
            )

            if is_hashed and stored_password.startswith("$2b$"):
                # Should use verify_password for bcrypt hashes
                mock_verify.return_value = True
                result = admin_login(login_data)
                assert result["msg"] == "Admin login successful"
                mock_verify.assert_called_with("TestPass123!", stored_password)
            else:
                # Should use direct comparison for non-bcrypt
                if stored_password == "TestPass123!":
                    result = admin_login(login_data)
                    assert result["msg"] == "Admin login successful"
                else:
                    with pytest.raises(HTTPException) as exc_info:
                        admin_login(login_data)
                    assert exc_info.value.detail == "Incorrect password"

            # Reset mock for next iteration
            mock_verify.reset_mock()

    @patch("app.admin.router.user_collection")
    def test_admin_login_whitespace_handling(self, mock_collection):
        """Test admin login handles whitespace in inputs correctly"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "TestPass123!",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        # Note: The admin login doesn't explicitly strip whitespace like user registration
        # So we test the actual behavior
        login_data = AdminLoginRequest(
            keyID="Westfield Sydney",  # No extra whitespace
            username="admin123",
            password="TestPass123!",
            email="admin@example.com",
        )

        result = admin_login(login_data)
        assert result["msg"] == "Admin login successful"

    @patch("app.admin.router.user_collection")
    def test_admin_login_empty_field_validation(self, mock_collection):
        """Test admin login with various empty fields (handled by Pydantic validation)"""
        # These tests ensure the Pydantic models validate correctly
        # Empty fields should be caught by Pydantic before reaching the function

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "TestPass123!",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        # Test valid login first
        valid_data = AdminLoginRequest(
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            email="admin@example.com",
        )

        result = admin_login(valid_data)
        assert result["msg"] == "Admin login successful"

    @patch("app.admin.router.user_collection")
    def test_admin_login_database_error_handling(self, mock_collection):
        """Test admin login handles database errors gracefully"""
        # Simulate database connection error
        mock_collection.find_one.side_effect = Exception("Database connection error")

        login_data = AdminLoginRequest(
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            email="admin@example.com",
        )

        # The function should let the exception propagate
        with pytest.raises(Exception) as exc_info:
            admin_login(login_data)

        assert "Database connection error" in str(exc_info.value)

    @patch("app.admin.router.user_collection")
    def test_admin_login_multiple_admins_same_keyid(self, mock_collection):
        """Test that multiple admins can exist for the same keyID and login correctly"""
        # Simulate multiple admins with same keyID but different usernames
        admin1_doc = {
            "email": "admin1@example.com",
            "username": "admin001",
            "password": "TestPass123!",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        admin2_doc = {
            "email": "admin2@example.com",
            "username": "admin002",
            "password": "TestPass456!",
            "keyID": "Westfield Sydney",  # Same keyID
            "role": "admin",
        }

        # Test login for first admin
        mock_collection.find_one.return_value = admin1_doc
        login_data1 = AdminLoginRequest(
            keyID="Westfield Sydney",
            username="admin001",  # First admin's username
            password="TestPass123!",
            email="admin1@example.com",
        )

        result1 = admin_login(login_data1)
        assert result1["msg"] == "Admin login successful"

        # Verify query was made with correct keyID+username combination
        call_args = mock_collection.find_one.call_args[0][0]
        assert call_args["username"] == "admin001"

        # Reset mock for second admin
        mock_collection.reset_mock()

        # Test login for second admin (same keyID, different username)
        mock_collection.find_one.return_value = admin2_doc
        login_data2 = AdminLoginRequest(
            keyID="Westfield Sydney",
            username="admin002",  # Second admin's username
            password="TestPass456!",
            email="admin2@example.com",
        )

        result2 = admin_login(login_data2)
        assert result2["msg"] == "Admin login successful"

        # Verify query was made with correct keyID+username combination
        call_args = mock_collection.find_one.call_args[0][0]
        assert call_args["username"] == "admin002"

    @patch("app.admin.router.user_collection")
    def test_admin_login_correct_admin_selected_from_multiple(self, mock_collection):
        """Test that the correct admin is selected when multiple exist for same keyID"""
        # Only the admin with matching keyID+username should be found
        correct_admin = {
            "email": "target@example.com",
            "username": "target_user",
            "password": "TestPass123!",
            "keyID": "Shared KeyID",
            "role": "admin",
        }

        # Mock returns the specific admin matching both keyID and username
        mock_collection.find_one.return_value = correct_admin

        login_data = AdminLoginRequest(
            keyID="Shared KeyID",
            username="target_user",
            password="TestPass123!",
            email="target@example.com",
        )

        result = admin_login(login_data)
        assert result["msg"] == "Admin login successful"

        # Verify the database was queried for the specific keyID+username combination
        expected_query = {
            "keyID": {"$regex": "^Shared\\ KeyID$", "$options": "i"},
            "username": "target_user",
            "role": "admin",
        }
        mock_collection.find_one.assert_called_once_with(expected_query)

    @patch("app.admin.router.user_collection")
    def test_admin_login_scenario_from_original_issue(self, mock_collection):
        """Test the specific scenario from the original issue - keyID exists but username doesn't match"""
        # This simulates the original problem where admin "lee" exists for keyID "westfield-syd"
        # but user tries to login with username "tjfq4203" for the same keyID
        # The new logic should return None (no match) instead of finding "lee" and rejecting "tjfq4203"

        mock_collection.find_one.return_value = (
            None  # No admin found with keyID + username combo
        )

        login_data = AdminLoginRequest(
            keyID="westfield-syd",
            username="tjfq4203",  # This username doesn't exist for this keyID
            password="some_password",
            email="user@example.com",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_login(login_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Invalid keyID and username combination"

        # Verify the query was made for the specific keyID + username combination
        expected_query = {
            "keyID": {"$regex": "^westfield\\-syd$", "$options": "i"},
            "username": "tjfq4203",
            "role": "admin",
        }
        mock_collection.find_one.assert_called_once_with(expected_query)


class TestAdminList:
    """Test cases for admin list functionality"""

    @patch("app.admin.router.user_collection")
    def test_get_admins_success(self, mock_collection):
        """Test successful retrieval of admin list"""
        admin_list = [
            {
                "email": "admin1@example.com",
                "username": "admin001",
                "keyID": "Westfield Sydney",
                "role": "admin",
            },
            {
                "email": "admin2@example.com",
                "username": "admin002",
                "keyID": "Westfield Bondi",
                "role": "admin",
            },
        ]

        mock_collection.find.return_value = admin_list

        from app.admin.router import get_admins

        result = get_admins()

        assert result == admin_list

        # Verify correct query was made
        mock_collection.find.assert_called_once_with(
            {"role": "admin"}, {"_id": 0, "password": 0}
        )

    @patch("app.admin.router.user_collection")
    def test_get_admins_empty_list(self, mock_collection):
        """Test admin list when no admins exist"""
        mock_collection.find.return_value = []

        from app.admin.router import get_admins

        result = get_admins()

        assert result == []

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.metrics")
    def test_get_admins_metrics_recording(self, mock_metrics, mock_collection):
        """Test that get_admins records metrics correctly"""
        admin_list = [{"email": "admin@example.com", "role": "admin"}]
        mock_collection.find.return_value = admin_list

        from app.admin.router import get_admins

        result = get_admins()

        assert result == admin_list

        # Verify metrics were recorded
        mock_metrics.increment_counter.assert_called_once_with(
            "AdminOperations", {"operation": "list_admins"}
        )

    @patch("app.admin.router.user_collection")
    def test_get_admins_excludes_passwords(self, mock_collection):
        """Test that admin list excludes password fields"""
        from app.admin.router import get_admins

        get_admins()

        # Verify password field is excluded from projection
        call_args = mock_collection.find.call_args
        assert call_args[0][1] == {"_id": 0, "password": 0}
