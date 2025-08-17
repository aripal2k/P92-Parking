import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from app.admin.router import (
    register_admin,
    admin_login,
    admin_edit_profile,
    admin_change_password,
    admin_edit_parking_rate,
    get_parking_slot_info,
    update_parking_slot_status,
    get_data_statistics,
    clear_all_test_data,
)
from app.admin.router import (
    AdminRegisterRequest,
    AdminLoginRequest,
    DataClearRequest,
    AdminEditParkingRateRequest,
    DestinationRatesRequest,
)
from app.auth.auth import AdminEdit, AdminChangePassword, AdminSlotStatusUpdate

# Integration tests for admin functionality
# Tests complete workflows combining multiple admin features


class TestAdminCompleteWorkflow:
    """Integration tests for complete admin workflow"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.generate_username")
    @patch("app.admin.router.generate_password")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.hash_password")
    def test_complete_admin_lifecycle(
        self,
        mock_hash,
        mock_verify,
        mock_generate_password,
        mock_generate_username,
        mock_collection,
    ):
        """Test complete admin lifecycle: register -> login -> edit profile -> change password"""

        # Setup mocks
        mock_generate_username.return_value = "admin001"
        mock_generate_password.return_value = "TempPass123!"
        mock_verify.return_value = True
        mock_hash.return_value = "new_hashed_password"

        # Track database state
        db_state = {}

        def mock_find_one(query):
            if "email" in query:
                return db_state.get(query["email"])
            elif "keyID" in query:
                # Handle case insensitive keyID lookup
                if "$regex" in query["keyID"]:
                    # Extract the keyID from the regex pattern
                    pattern = query["keyID"]["$regex"]
                    # Remove regex anchors and escape characters
                    keyid_search = (
                        pattern.replace("^", "").replace("$", "").replace("\\", "")
                    )
                    for email, admin in db_state.items():
                        if (
                            admin
                            and admin.get("keyID", "").lower() == keyid_search.lower()
                        ):
                            return admin
                else:
                    # Direct keyID match
                    for email, admin in db_state.items():
                        if admin and admin.get("keyID") == query["keyID"]:
                            return admin
            return None

        def mock_insert_one(doc):
            db_state[doc["email"]] = doc
            return MagicMock()

        def mock_update_one(query, update):
            if "keyID" in query:
                for email, admin in db_state.items():
                    if admin and admin.get("keyID") == query["keyID"]:
                        admin.update(update["$set"])
                        break
            return MagicMock()

        mock_collection.find_one.side_effect = mock_find_one
        mock_collection.insert_one.side_effect = mock_insert_one
        mock_collection.update_one.side_effect = mock_update_one

        # Step 1: Register admin
        register_data = AdminRegisterRequest(
            email="admin@westfield.com", keyID="Westfield Sydney"
        )

        register_result = register_admin(register_data)

        assert register_result["msg"] == "Admin registered successfully"
        assert register_result["username"] == "admin001"
        assert register_result["password"] == "TempPass123!"

        # Verify admin was added to database
        assert "admin@westfield.com" in db_state
        admin_record = db_state["admin@westfield.com"]
        assert admin_record["role"] == "admin"
        assert admin_record["keyID"] == "Westfield Sydney"

        # Step 2: Login with generated credentials
        login_data = AdminLoginRequest(
            keyID="westfield sydney",  # Case insensitive
            username="admin001",
            password="TempPass123!",
            email="admin@westfield.com",
        )

        login_result = admin_login(login_data)

        assert login_result["msg"] == "Admin login successful"

        # Step 3: Edit profile (change username)
        edit_data = AdminEdit(
            keyID="Westfield Sydney",
            current_username="admin001",
            current_password="TempPass123!",
            new_username="sydney_admin",
        )

        edit_result = admin_edit_profile(edit_data)

        assert edit_result["success"] is True
        assert edit_result["admin_info"]["username"] == "sydney_admin"
        assert (
            "username=sydney_admin" in edit_result["changes_summary"]["changed_fields"]
        )

        # Verify username was updated in database
        assert db_state["admin@westfield.com"]["username"] == "sydney_admin"

        # Step 4: Change password
        change_password_data = AdminChangePassword(
            keyID="Westfield Sydney",
            current_username="sydney_admin",  # Updated username
            current_password="TempPass123!",
            new_password="NewSecurePass456@",
            confirm_new_password="NewSecurePass456@",
        )

        password_result = admin_change_password(change_password_data)

        assert password_result["msg"] == "Password changed successfully."

        # Verify password was hashed and updated
        mock_hash.assert_called_with("NewSecurePass456@")
        assert db_state["admin@westfield.com"]["password"] == "new_hashed_password"

        # Step 5: Login with new credentials
        mock_verify.reset_mock()
        mock_verify.return_value = True  # Mock successful password verification

        new_login_data = AdminLoginRequest(
            keyID="Westfield Sydney",
            username="sydney_admin",  # New username
            password="NewSecurePass456@",  # New password
            email="admin@westfield.com",
        )

        # Update admin record to have hashed password for login test
        db_state["admin@westfield.com"]["password"] = "$2b$12$new_hashed_password"

        new_login_result = admin_login(new_login_data)

        assert new_login_result["msg"] == "Admin login successful"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.parking.utils.load_parking_rates")
    @patch("app.admin.router.save_parking_rates")
    @patch("app.admin.router.find_slot_by_id_with_context")
    @patch("app.admin.router.storage_manager")
    def test_admin_parking_management_workflow(
        self,
        mock_storage,
        mock_find_slot,
        mock_save_rates,
        mock_load_rates,
        mock_verify,
        mock_collection,
    ):
        """Test complete admin parking management workflow: edit rates -> get slot info -> update slot"""

        mock_verify.return_value = True
        mock_save_rates.return_value = True

        # Mock admin authentication and user validation
        admin_doc = {
            "email": "admin@westfield.com",
            "username": "sydney_admin",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }

        # Mock user for slot update validation
        regular_user = {"username": "user123", "role": "user"}

        def mock_find_one(query):
            if "keyID" in query:
                return admin_doc
            elif "username" in query and query["username"] == "user123":
                return regular_user
            return None

        mock_collection.find_one.side_effect = mock_find_one

        # Step 1: Edit parking rates
        mock_load_rates.return_value = {
            "currency": "AUD",
            "default_rates": {"base_rate_per_hour": 5.0},
            "destinations": {},
        }

        rate_request = AdminEditParkingRateRequest(
            destination="Westfield Sydney",
            rates=DestinationRatesRequest(
                base_rate_per_hour="8.0",
                peak_hour_surcharge_rate="0.6",
                weekend_surcharge_rate="0.4",
                public_holiday_surcharge_rate="1.2",
            ),
            keyID="Westfield Sydney",
            username="sydney_admin",
            password="SecurePass123!",
        )

        rate_result = admin_edit_parking_rate(rate_request)

        assert rate_result["success"] is True
        assert rate_result["destination"] == "Westfield Sydney"
        assert rate_result["updated_rates"]["base_rate_per_hour"] == 8.0

        # Step 2: Get parking slot info
        mock_slot_info = {
            "slot": {"slot_id": "A1", "status": "available", "x": 100, "y": 150},
            "map_id": "map123",
            "building_name": "Westfield Sydney",
            "level": 1,
        }
        mock_find_slot.return_value = mock_slot_info

        slot_info_result = get_parking_slot_info(
            slot_id="A1",
            keyID="Westfield Sydney",
            username="sydney_admin",
            password="SecurePass123!",
            building_name="Westfield Sydney",
            level=1,
        )

        assert slot_info_result["success"] is True
        assert slot_info_result["slots"][0]["slot_id"] == "A1"
        assert slot_info_result["slots"][0]["status"] == "available"

        # Step 3: Update slot status
        mock_storage.find_slot_by_id.return_value = mock_slot_info
        mock_storage.update_slot_status.return_value = True

        update_request = AdminSlotStatusUpdate(
            slot_id="A1",
            new_status="occupied",
            vehicle_id="NSW123ABC",
            reserved_by="user123",
            keyID="Westfield Sydney",
            username="sydney_admin",
            password="SecurePass123!",
            building_name="Westfield Sydney",
            level=1,
        )

        update_result = update_parking_slot_status(update_request)

        assert update_result["success"] is True
        assert update_result["old_status"] == "available"
        assert update_result["new_status"] == "occupied"
        assert update_result["vehicle_id"] == "NSW123ABC"
        assert update_result["reserved_by"] == "user123"

        # Verify storage update was called correctly
        mock_storage.update_slot_status.assert_called_with(
            slot_id="A1",
            new_status="occupied",
            vehicle_id="NSW123ABC",
            reserved_by="user123",
        )

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.storage_manager")
    @patch("app.admin.router.db")
    def test_admin_data_management_workflow(
        self, mock_db, mock_storage, mock_user_collection
    ):
        """Test complete admin data management workflow: check stats -> clear data -> verify stats"""

        # Step 1: Get initial data statistics
        mock_user_collection.count_documents.side_effect = [
            50,
            45,
            5,
        ]  # total, regular, admin
        mock_storage.get_storage_stats.return_value = {
            "total_analyses": 25,
            "total_size_mb": 150.7,
        }

        initial_stats = get_data_statistics()

        assert initial_stats["users"]["total"] == 50
        assert initial_stats["users"]["regular_users"] == 45
        assert initial_stats["users"]["admins"] == 5
        assert initial_stats["parking_maps"]["total"] == 25
        assert initial_stats["parking_maps"]["total_size_mb"] == 150.7

        # Step 2: Clear all data
        mock_storage.get_storage_stats.return_value = {"total_size_mb": 150.7}
        mock_user_collection.delete_many.return_value = MagicMock(deleted_count=50)

        # Mock collections
        mock_maps_collection = MagicMock()
        mock_maps_collection.delete_many.return_value = MagicMock(deleted_count=25)
        mock_qrcodes_collection = MagicMock()
        mock_qrcodes_collection.delete_many.return_value = MagicMock(deleted_count=10)
        mock_db.maps = mock_maps_collection
        mock_db.qrcodes = mock_qrcodes_collection

        clear_request = DataClearRequest(admin_password="123456")

        clear_result = clear_all_test_data(clear_request)

        assert clear_result["message"] == "All test data cleared successfully"
        assert clear_result["cleared_data"]["users_deleted"] == 50
        assert clear_result["cleared_data"]["maps_deleted"] == 25
        assert clear_result["cleared_data"]["qrcodes_deleted"] == 10
        assert clear_result["cleared_data"]["storage_cleared_mb"] == 150.7

        # Step 3: Verify data is cleared (get stats again)
        mock_user_collection.count_documents.side_effect = [
            0,
            0,
            0,
        ]  # All zero after clearing
        mock_storage.get_storage_stats.return_value = {
            "total_analyses": 0,
            "total_size_mb": 0.0,
        }

        final_stats = get_data_statistics()

        assert final_stats["users"]["total"] == 0
        assert final_stats["users"]["regular_users"] == 0
        assert final_stats["users"]["admins"] == 0
        assert final_stats["parking_maps"]["total"] == 0
        assert final_stats["parking_maps"]["total_size_mb"] == 0.0


class TestAdminErrorHandlingWorkflows:
    """Integration tests for admin error handling across multiple operations"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_authentication_failure_propagation(self, mock_verify, mock_collection):
        """Test that authentication failures are consistent across all admin operations"""

        # Test with invalid keyID across multiple operations
        mock_collection.find_one.return_value = None

        operations_to_test = [
            (
                admin_edit_profile,
                AdminEdit(
                    keyID="Invalid KeyID",
                    current_username="admin",
                    current_password="pass",
                    new_username="new",
                ),
            ),
            (
                admin_change_password,
                AdminChangePassword(
                    keyID="Invalid KeyID",
                    current_username="admin",
                    current_password="old",
                    new_password="new123!",
                    confirm_new_password="new123!",
                ),
            ),
        ]

        for operation, data in operations_to_test:
            with pytest.raises(HTTPException) as exc_info:
                operation(data)

            assert exc_info.value.status_code == 401
            assert exc_info.value.detail == "Invalid keyID and username combination"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_authorization_consistency(self, mock_verify, mock_collection):
        """Test that authorization checks are consistent across operations"""

        # Test with non-admin role
        mock_verify.return_value = True
        non_admin_doc = {
            "email": "user@example.com",
            "username": "user123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Some KeyID",
            "role": "user",  # Not admin
        }
        mock_collection.find_one.return_value = non_admin_doc

        operations_to_test = [
            (
                admin_edit_profile,
                AdminEdit(
                    keyID="Some KeyID",
                    current_username="user123",
                    current_password="pass",
                    new_username="new",
                ),
            ),
            (
                admin_change_password,
                AdminChangePassword(
                    keyID="Some KeyID",
                    current_username="user123",
                    current_password="old",
                    new_password="new123!",
                    confirm_new_password="new123!",
                ),
            ),
        ]

        for operation, data in operations_to_test:
            with pytest.raises(HTTPException) as exc_info:
                operation(data)

            assert exc_info.value.status_code == 401
            assert "Access denied. Admin role required." in exc_info.value.detail

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.find_slot_by_id_with_context")
    @patch("app.admin.router.storage_manager")
    def test_parking_operations_error_consistency(
        self, mock_storage, mock_find_slot, mock_verify, mock_collection
    ):
        """Test that parking operations handle errors consistently"""

        mock_verify.return_value = True
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }

        # Mock user for validation
        regular_user = {"username": "user123", "role": "user"}

        def mock_find_one(query):
            if "keyID" in query:
                return admin_doc
            elif "username" in query and query["username"] == "user123":
                return regular_user
            return None

        mock_collection.find_one.side_effect = mock_find_one

        # Test slot not found across operations
        mock_find_slot.return_value = None

        # Test get slot info
        with pytest.raises(HTTPException) as exc_info:
            get_parking_slot_info(
                slot_id="NONEXISTENT",
                keyID="Westfield Sydney",
                username="admin123",
                password="TestPass123!",
                building_name="Westfield Sydney",
            )

        assert exc_info.value.status_code == 404
        assert exc_info.value.detail == "Parking slot not found"

        # Test update slot status
        update_data = AdminSlotStatusUpdate(
            slot_id="NONEXISTENT",
            new_status="occupied",
            reserved_by="user123",  # Add required field
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            building_name="Westfield Sydney",
        )

        with pytest.raises(HTTPException) as exc_info:
            update_parking_slot_status(update_data)

        assert exc_info.value.status_code == 404
        assert exc_info.value.detail == "Parking slot not found"


class TestAdminConcurrencyScenarios:
    """Integration tests for admin operations under concurrent access scenarios"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.generate_username")
    @patch("app.admin.router.generate_password")
    def test_concurrent_admin_registration(
        self, mock_generate_password, mock_generate_username, mock_collection
    ):
        """Test concurrent admin registration with same email"""

        mock_generate_username.return_value = "admin001"
        mock_generate_password.return_value = "TempPass123!"

        # First registration succeeds
        mock_collection.find_one.return_value = None
        mock_collection.insert_one.return_value = MagicMock()

        register_data = AdminRegisterRequest(
            email="admin@example.com", keyID="Westfield Sydney"
        )

        result1 = register_admin(register_data)
        assert result1["msg"] == "Admin registered successfully"

        # Second registration with same email fails
        mock_collection.find_one.return_value = {"email": "admin@example.com"}

        with pytest.raises(HTTPException) as exc_info:
            register_admin(register_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Email already registered"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.storage_manager")
    @patch("app.admin.router.find_slot_by_id_with_context")
    def test_concurrent_slot_updates(
        self, mock_find_slot, mock_storage, mock_verify, mock_collection
    ):
        """Test concurrent slot updates by different admins"""

        mock_verify.return_value = True

        # Mock admin authentication and user validation
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }

        # Mock users for validation
        user1 = {"username": "user1", "role": "user"}
        user2 = {"username": "user2", "role": "user"}

        def mock_find_one(query):
            if "keyID" in query:
                return admin_doc
            elif "username" in query:
                if query["username"] == "user1":
                    return user1
                elif query["username"] == "user2":
                    return user2
            return None

        mock_collection.find_one.side_effect = mock_find_one

        # Mock slot info
        mock_slot_info = {
            "slot": {"slot_id": "A1", "status": "available"},
            "map_id": "map123",
            "building_name": "Westfield Sydney",
            "level": 1,
        }
        mock_find_slot.return_value = mock_slot_info
        mock_storage.find_slot_by_id.return_value = mock_slot_info

        # First update succeeds
        mock_storage.update_slot_status.return_value = True

        update_data1 = AdminSlotStatusUpdate(
            slot_id="A1",
            new_status="occupied",
            vehicle_id="NSW123",
            reserved_by="user1",
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            building_name="Westfield Sydney",
        )

        result1 = update_parking_slot_status(update_data1)
        assert result1["success"] is True
        assert result1["new_status"] == "occupied"

        # Second update (simulate concurrent access) - storage fails
        mock_storage.update_slot_status.return_value = False

        update_data2 = AdminSlotStatusUpdate(
            slot_id="A1",
            new_status="allocated",
            vehicle_id="NSW456",
            reserved_by="user2",
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            building_name="Westfield Sydney",
        )

        with pytest.raises(HTTPException) as exc_info:
            update_parking_slot_status(update_data2)

        assert exc_info.value.status_code == 500
        assert exc_info.value.detail == "Failed to update parking slot"


class TestAdminPermissionBoundaries:
    """Integration tests for admin permission boundaries and authorization"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.parking.utils.load_parking_rates")
    def test_destination_authorization_boundaries(
        self, mock_load_rates, mock_verify, mock_collection
    ):
        """Test admin authorization boundaries for different destinations"""

        mock_verify.return_value = True
        mock_load_rates.return_value = {"currency": "AUD", "destinations": {}}

        # Sydney admin
        sydney_admin = {
            "email": "sydney@example.com",
            "username": "sydney_admin",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }

        # Bondi admin
        bondi_admin = {
            "email": "bondi@example.com",
            "username": "bondi_admin",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Bondi",
            "role": "admin",
        }

        # Test Sydney admin can edit Sydney rates
        mock_collection.find_one.return_value = sydney_admin

        sydney_request = AdminEditParkingRateRequest(
            destination="Westfield Sydney",
            rates=DestinationRatesRequest(base_rate_per_hour="8.0"),
            keyID="Westfield Sydney",
            username="sydney_admin",
            password="TestPass123!",
        )

        # This should succeed (same location)
        with patch("app.admin.router.save_parking_rates", return_value=True):
            result = admin_edit_parking_rate(sydney_request)
            assert result["success"] is True

        # Test Sydney admin cannot edit Bondi rates
        bondi_request = AdminEditParkingRateRequest(
            destination="Westfield Bondi",  # Different destination
            rates=DestinationRatesRequest(base_rate_per_hour="8.0"),
            keyID="Westfield Sydney",  # Sydney admin keyID
            username="sydney_admin",
            password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_parking_rate(bondi_request)

        assert exc_info.value.status_code == 403
        assert (
            "not authorize you to edit rates for this destination"
            in exc_info.value.detail
        )

        # Test Bondi admin can edit Bondi rates
        mock_collection.find_one.return_value = bondi_admin

        bondi_request_valid = AdminEditParkingRateRequest(
            destination="Westfield Bondi",
            rates=DestinationRatesRequest(base_rate_per_hour="9.0"),
            keyID="Westfield Bondi",  # Bondi admin keyID
            username="bondi_admin",
            password="TestPass123!",
        )

        with patch("app.admin.router.save_parking_rates", return_value=True):
            result = admin_edit_parking_rate(bondi_request_valid)
            assert result["success"] is True
            assert result["destination"] == "Westfield Bondi"
