import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from app.admin.router import get_parking_slot_info, update_parking_slot_status
from app.auth.auth import AdminSlotStatusUpdate

# test cases for admin parking slot management
# APIs:
# /admin/parking/slot/info
# /admin/parking/slot/update


class TestAdminGetParkingSlotInfo:
    """Test cases for admin parking slot info functionality"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.find_slot_by_id_with_context")
    def test_get_parking_slot_info_success(
        self, mock_find_slot, mock_verify, mock_collection
    ):
        """Test successful parking slot info retrieval"""
        mock_verify.return_value = True

        # Mock admin authentication
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        # Mock slot info
        mock_slot_info = {
            "slot": {
                "slot_id": "A1",
                "status": "occupied",
                "x": 100,
                "y": 150,
                "vehicle_id": "NSW123",
                "reserved_by": "user123",
            },
            "map_id": "map123",
            "building_name": "Westfield Sydney",
            "level": 1,
        }
        mock_find_slot.return_value = mock_slot_info

        result = get_parking_slot_info(
            slot_id="A1",
            keyID="westfield sydney",  # Case insensitive
            username="admin123",
            password="TestPass123!",
            building_name="Westfield Sydney",
            level=1,
        )

        assert result["success"] is True
        assert result["building_name"] == "Westfield Sydney"
        assert result["map_id"] == "map123"
        assert result["level_filter"] == 1
        assert len(result["slots"]) == 1
        assert result["slots"][0]["slot_id"] == "A1"
        assert result["slots"][0]["status"] == "occupied"

    @patch("app.admin.router.user_collection")
    def test_get_parking_slot_info_invalid_keyid(self, mock_collection):
        """Test parking slot info with invalid keyID"""
        mock_collection.find_one.return_value = None

        with pytest.raises(HTTPException) as exc_info:
            get_parking_slot_info(
                slot_id="A1",
                keyID="Invalid KeyID",
                username="admin123",
                password="TestPass123!",
            )

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Invalid keyID and username combination"

    @patch("app.admin.router.user_collection")
    def test_get_parking_slot_info_username_mismatch(self, mock_collection):
        """Test parking slot info with wrong username for keyID (new logic returns no match)"""
        # With new authentication logic, wrong username for keyID returns None from database
        mock_collection.find_one.return_value = (
            None  # No admin found with this keyID+username combo
        )

        with pytest.raises(HTTPException) as exc_info:
            get_parking_slot_info(
                slot_id="A1",
                keyID="Westfield Sydney",
                username="wronguser",  # Wrong username for this keyID
                password="TestPass123!",
            )

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Invalid keyID and username combination"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_get_parking_slot_info_incorrect_password(
        self, mock_verify, mock_collection
    ):
        """Test parking slot info with incorrect password"""
        mock_verify.return_value = False

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        with pytest.raises(HTTPException) as exc_info:
            get_parking_slot_info(
                slot_id="A1",
                keyID="Westfield Sydney",
                username="admin123",
                password="WrongPassword!",
            )

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Incorrect password"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_get_parking_slot_info_non_admin_role(self, mock_verify, mock_collection):
        """Test parking slot info with non-admin role"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "user",  # Not admin
        }
        mock_collection.find_one.return_value = admin_doc

        with pytest.raises(HTTPException) as exc_info:
            get_parking_slot_info(
                slot_id="A1",
                keyID="Westfield Sydney",
                username="admin123",
                password="TestPass123!",
            )

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Access denied. Admin role required."

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.find_slot_by_id_with_context")
    def test_get_parking_slot_info_slot_not_found(
        self, mock_find_slot, mock_verify, mock_collection
    ):
        """Test parking slot info when slot is not found"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc
        mock_find_slot.return_value = None  # Slot not found

        with pytest.raises(HTTPException) as exc_info:
            get_parking_slot_info(
                slot_id="NONEXISTENT",
                keyID="Westfield Sydney",
                username="admin123",
                password="TestPass123!",
            )

        assert exc_info.value.status_code == 404
        assert exc_info.value.detail == "Parking slot not found"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.find_slot_by_id_with_context")
    def test_get_parking_slot_info_context_mismatch(
        self, mock_find_slot, mock_verify, mock_collection
    ):
        """Test parking slot info with context mismatch"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        # Slot found but in different context
        mock_slot_info = {
            "slot": {"slot_id": "A1", "status": "available"},
            "map_id": "different_map",
            "building_name": "Different Building",
            "level": 2,
        }
        mock_find_slot.return_value = mock_slot_info

        with pytest.raises(HTTPException) as exc_info:
            get_parking_slot_info(
                slot_id="A1",
                keyID="Westfield Sydney",
                username="admin123",
                password="TestPass123!",
                building_name="Westfield Sydney",  # Different from actual
                level=1,  # Different from actual
            )

        assert exc_info.value.status_code == 400
        assert "Slot 'A1' found but not in the specified" in exc_info.value.detail

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.find_slot_by_id_with_context")
    def test_get_parking_slot_info_plain_password(
        self, mock_find_slot, mock_verify, mock_collection
    ):
        """Test parking slot info with plain text password"""
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "TestPass123!",  # Plain text password
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        mock_slot_info = {
            "slot": {"slot_id": "A1", "status": "available"},
            "map_id": "map123",
            "building_name": "Westfield Sydney",
            "level": 1,
        }
        mock_find_slot.return_value = mock_slot_info

        result = get_parking_slot_info(
            slot_id="A1",
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
        )

        assert result["success"] is True
        assert result["slots"][0]["slot_id"] == "A1"


class TestAdminUpdateParkingSlotStatus:
    """Test cases for admin parking slot status update functionality"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.find_slot_by_id_with_context")
    @patch("app.admin.router.storage_manager")
    def test_update_parking_slot_status_success(
        self, mock_storage, mock_find_slot, mock_verify, mock_collection
    ):
        """Test successful parking slot status update"""
        mock_verify.return_value = True

        # Mock admin authentication and user validation
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }

        # Mock user for reserved_by validation
        regular_user = {"username": "user123", "role": "user"}

        def mock_find_one(query):
            if "keyID" in query:
                return admin_doc
            elif "username" in query and query["username"] == "user123":
                return regular_user
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

        # Mock database slot info and update
        mock_storage.find_slot_by_id.return_value = {
            "slot": {"slot_id": "A1", "status": "available"},
            "map_id": "map123",
            "building_name": "Westfield Sydney",
            "level": 1,
        }
        mock_storage.update_slot_status.return_value = True

        update_data = AdminSlotStatusUpdate(
            slot_id="A1",
            new_status="occupied",
            vehicle_id="NSW123",
            reserved_by="user123",
            keyID="westfield sydney",  # Case insensitive
            username="admin123",
            password="TestPass123!",
            building_name="Westfield Sydney",
            level=1,
        )

        result = update_parking_slot_status(update_data)

        assert result["success"] is True
        assert result["message"] == "Parking slot status updated successfully"
        assert result["slot_id"] == "A1"
        assert result["old_status"] == "available"
        assert result["new_status"] == "occupied"
        assert result["updated_by"] == "admin123"
        assert result["vehicle_id"] == "NSW123"
        assert result["reserved_by"] == "user123"

        # Verify storage update was called
        mock_storage.update_slot_status.assert_called_once_with(
            slot_id="A1",
            new_status="occupied",
            vehicle_id="NSW123",
            reserved_by="user123",
        )

    @patch("app.admin.router.user_collection")
    def test_update_parking_slot_status_invalid_keyid(self, mock_collection):
        """Test parking slot update with invalid keyID"""
        # Mock regular user for validation but no admin
        regular_user = {"username": "user123", "role": "user"}

        def mock_find_one(query):
            if "username" in query and query["username"] == "user123":
                return regular_user
            return None  # No admin found

        mock_collection.find_one.side_effect = mock_find_one

        update_data = AdminSlotStatusUpdate(
            slot_id="A1",
            new_status="occupied",
            reserved_by="user123",  # Add required field
            keyID="Invalid KeyID",
            username="admin123",
            password="TestPass123!",
            building_name="Westfield Sydney",
        )

        with pytest.raises(HTTPException) as exc_info:
            update_parking_slot_status(update_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Invalid keyID and username combination"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_update_parking_slot_status_no_context(self, mock_verify, mock_collection):
        """Test parking slot update with no context provided"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        update_data = AdminSlotStatusUpdate(
            slot_id="A1",
            new_status="occupied",
            reserved_by="user123",  # Required for occupied status
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            # No building_name, map_id, or level provided
        )

        with pytest.raises(HTTPException) as exc_info:
            update_parking_slot_status(update_data)

        assert exc_info.value.status_code == 400
        assert (
            "At least one of building_name, map_id, or level must be provided"
            in exc_info.value.detail
        )

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.find_slot_by_id_with_context")
    def test_update_parking_slot_status_slot_not_found(
        self, mock_find_slot, mock_verify, mock_collection
    ):
        """Test parking slot update when slot is not found"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc
        mock_find_slot.return_value = None  # Slot not found

        # Add mock user for validation
        regular_user = {"username": "user123", "role": "user"}

        def mock_find_one(query):
            if "keyID" in query:
                return admin_doc
            elif "username" in query and query["username"] == "user123":
                return regular_user
            return None

        mock_collection.find_one.side_effect = mock_find_one

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

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.find_slot_by_id_with_context")
    @patch("app.admin.router.storage_manager")
    def test_update_parking_slot_status_available_clears_fields(
        self, mock_storage, mock_find_slot, mock_verify, mock_collection
    ):
        """Test that setting status to available clears vehicle_id and reserved_by"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        mock_slot_info = {
            "slot": {"slot_id": "A1", "status": "occupied"},
            "map_id": "map123",
            "building_name": "Westfield Sydney",
            "level": 1,
        }
        mock_find_slot.return_value = mock_slot_info
        mock_storage.find_slot_by_id.return_value = mock_slot_info
        mock_storage.update_slot_status.return_value = True

        update_data = AdminSlotStatusUpdate(
            slot_id="A1",
            new_status="available",
            vehicle_id="NSW123",  # Should be ignored for available status
            reserved_by="user123",  # Should be ignored for available status
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            building_name="Westfield Sydney",
        )

        result = update_parking_slot_status(update_data)

        assert result["success"] is True
        assert result["new_status"] == "available"
        assert result["vehicle_id"] is None  # Should be cleared
        assert result["reserved_by"] is None  # Should be cleared

        # Verify storage update was called with cleared fields
        mock_storage.update_slot_status.assert_called_once_with(
            slot_id="A1", new_status="available", vehicle_id=None, reserved_by=None
        )

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.find_slot_by_id_with_context")
    @patch("app.admin.router.storage_manager")
    def test_update_parking_slot_status_storage_failure(
        self, mock_storage, mock_find_slot, mock_verify, mock_collection
    ):
        """Test parking slot update with storage failure"""
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

        mock_slot_info = {
            "slot": {"slot_id": "A1", "status": "available"},
            "map_id": "map123",
            "building_name": "Westfield Sydney",
            "level": 1,
        }
        mock_find_slot.return_value = mock_slot_info
        mock_storage.find_slot_by_id.return_value = mock_slot_info
        mock_storage.update_slot_status.return_value = False  # Update fails

        update_data = AdminSlotStatusUpdate(
            slot_id="A1",
            new_status="occupied",
            reserved_by="user123",  # Add required field
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            building_name="Westfield Sydney",
        )

        with pytest.raises(HTTPException) as exc_info:
            update_parking_slot_status(update_data)

        assert exc_info.value.status_code == 500
        assert exc_info.value.detail == "Failed to update parking slot"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.find_slot_by_id_with_context")
    @patch("app.admin.router.storage_manager")
    @patch("app.admin.router.copy")
    @patch("datetime.datetime")
    def test_update_parking_slot_status_example_data_conversion(
        self,
        mock_datetime,
        mock_copy,
        mock_storage,
        mock_find_slot,
        mock_verify,
        mock_collection,
    ):
        """Test parking slot update with example data conversion"""
        mock_verify.return_value = True
        mock_datetime.utcnow.return_value.isoformat.return_value = "2023-01-01T00:00:00"

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

        # Mock example data (EXAMPLE_MAP_ID)
        from app.parking.utils import EXAMPLE_MAP_ID

        mock_slot_info = {
            "slot": {"slot_id": "A1", "status": "available"},
            "map_id": EXAMPLE_MAP_ID,  # Example data
            "building_name": "Westfield Sydney",
            "level": 1,
        }
        mock_find_slot.return_value = mock_slot_info

        # Mock example map data
        mock_copy.deepcopy.return_value = {"example": "map_data"}

        # Mock successful conversion
        mock_storage.save_image_and_analysis.return_value = "new_analysis_id"
        mock_storage.find_slot_by_id.return_value = None  # No database entry initially
        mock_storage.update_slot_status.return_value = True

        update_data = AdminSlotStatusUpdate(
            slot_id="A1",
            new_status="occupied",
            reserved_by="user123",  # Add required field
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            building_name="Westfield Sydney",
        )

        result = update_parking_slot_status(update_data)

        assert result["success"] is True
        assert result["converted_from_example"] is True
        assert result["conversion_info"]["original_map_id"] == EXAMPLE_MAP_ID
        assert result["conversion_info"]["new_map_id"] == "new_analysis_id"
        assert "example data converted to database" in result["message"].lower()

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.find_slot_by_id_with_context")
    @patch("app.admin.router.storage_manager")
    def test_update_parking_slot_status_example_conversion_failure(
        self, mock_storage, mock_find_slot, mock_verify, mock_collection
    ):
        """Test parking slot update with example data conversion failure"""
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

        # Mock example data
        from app.parking.utils import EXAMPLE_MAP_ID

        mock_slot_info = {
            "slot": {"slot_id": "A1", "status": "available"},
            "map_id": EXAMPLE_MAP_ID,
            "building_name": "Westfield Sydney",
            "level": 1,
        }
        mock_find_slot.return_value = mock_slot_info

        # Mock conversion failure
        mock_storage.save_image_and_analysis.side_effect = Exception(
            "Conversion failed"
        )

        update_data = AdminSlotStatusUpdate(
            slot_id="A1",
            new_status="occupied",
            reserved_by="user123",  # Add required field
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            building_name="Westfield Sydney",
        )

        with pytest.raises(HTTPException) as exc_info:
            update_parking_slot_status(update_data)

        assert exc_info.value.status_code == 500
        assert "Failed to convert example data to database" in exc_info.value.detail

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.admin.router.find_slot_by_id_with_context")
    @patch("app.admin.router.storage_manager")
    @patch("app.admin.router.metrics")
    def test_update_parking_slot_status_metrics_recording(
        self, mock_metrics, mock_storage, mock_find_slot, mock_verify, mock_collection
    ):
        """Test that parking slot update records metrics correctly"""
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

        mock_slot_info = {
            "slot": {"slot_id": "A1", "status": "available"},
            "map_id": "map123",
            "building_name": "Westfield Sydney",
            "level": 1,
        }
        mock_find_slot.return_value = mock_slot_info
        mock_storage.find_slot_by_id.return_value = mock_slot_info
        mock_storage.update_slot_status.return_value = True

        update_data = AdminSlotStatusUpdate(
            slot_id="A1",
            new_status="occupied",
            reserved_by="user123",  # Add required field
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
            building_name="Westfield Sydney",
        )

        result = update_parking_slot_status(update_data)

        assert result["success"] is True

        # Verify metrics were recorded
        mock_metrics.record_auth_event.assert_called_once_with(
            "admin_update_slot_status", True
        )
        mock_metrics.increment_counter.assert_called_once_with(
            "AdminOperations", {"operation": "update_slot_status"}
        )


class TestAdminParkingUtilities:
    """Test cases for admin parking utility functions"""

    @patch("app.admin.router.storage_manager")
    @patch("app.admin.router.get_map_data")
    def test_find_slot_by_id_with_context_database_priority(
        self, mock_get_map_data, mock_storage
    ):
        """Test that database data is found when no map context is provided"""
        from app.admin.router import find_slot_by_id_with_context

        # Mock database result
        mock_storage.find_slot_by_id.return_value = {
            "slot": {"slot_id": "A1", "status": "occupied"},
            "map_id": "db_map_id",
            "building_name": "Database Building",
            "level": 1,
        }

        # Call without building_name to trigger database search path
        result = find_slot_by_id_with_context("A1")

        # Should return database result
        assert result["map_id"] == "db_map_id"
        assert result["building_name"] == "Database Building"
        assert result["slot"]["status"] == "occupied"  # Database status

    @patch("app.admin.router.storage_manager")
    @patch("app.admin.router.get_map_data")
    def test_find_slot_by_id_with_context_fallback_to_example(
        self, mock_get_map_data, mock_storage
    ):
        """Test fallback to example data when not found in database"""
        from app.admin.router import find_slot_by_id_with_context

        # Mock no database result
        mock_storage.find_slot_by_id.return_value = None

        # Mock example data
        mock_get_map_data.return_value = {
            "_id": "example_map_id",
            "building_name": "Example Building",
            "parking_map": [
                {"level": 1, "slots": [{"slot_id": "A1", "status": "available"}]}
            ],
        }

        result = find_slot_by_id_with_context("A1", "Example Building")

        # Should return example data
        assert result["map_id"] == "example_map_id"
        assert result["building_name"] == "Example Building"
        assert result["slot"]["status"] == "available"

    @patch("app.admin.router.storage_manager")
    @patch("app.admin.router.get_map_data")
    def test_find_slot_by_id_with_context_not_found(
        self, mock_get_map_data, mock_storage
    ):
        """Test when slot is not found anywhere"""
        from app.admin.router import find_slot_by_id_with_context

        # Mock no results anywhere
        mock_storage.find_slot_by_id.return_value = None
        mock_get_map_data.return_value = None

        result = find_slot_by_id_with_context("NONEXISTENT", "Some Building")

        assert result is None

    @patch("app.admin.router.storage_manager")
    @patch("app.admin.router.get_map_data")
    def test_find_slot_by_id_with_context_level_filtering(
        self, mock_get_map_data, mock_storage
    ):
        """Test level filtering in slot search"""
        from app.admin.router import find_slot_by_id_with_context

        mock_storage.find_slot_by_id.return_value = None

        # Mock map data with multiple levels
        mock_get_map_data.return_value = {
            "_id": "map_id",
            "building_name": "Test Building",
            "parking_map": [
                {"level": 1, "slots": [{"slot_id": "A1", "status": "available"}]},
                {
                    "level": 2,
                    "slots": [
                        {"slot_id": "A1", "status": "occupied"}
                    ],  # Same slot_id, different level
                },
            ],
        }

        # Search for level 2 specifically
        result = find_slot_by_id_with_context("A1", "Test Building", level=2)

        assert result is not None
        assert result["level"] == 2
        assert result["slot"]["status"] == "occupied"  # Level 2 slot
