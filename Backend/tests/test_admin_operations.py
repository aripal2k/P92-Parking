import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from app.admin.router import (
    get_data_statistics,
    clear_all_test_data,
    admin_edit_parking_rate,
    normalize_destination_name,
    is_admin_authorized_for_destination,
    parse_rate_value,
    save_parking_rates,
)
from app.admin.router import (
    DataClearRequest,
    AdminEditParkingRateRequest,
    DestinationRatesRequest,
)

# test cases for admin operations
# APIs:
# /admin/data-stats
# /admin/clear-all-data
# /admin/admin_edit_parking_rate


class TestAdminDataStatistics:
    """Test cases for admin data statistics functionality"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.storage_manager")
    def test_get_data_statistics_success(self, mock_storage, mock_user_collection):
        """Test successful retrieval of data statistics"""
        # Mock user statistics
        mock_user_collection.count_documents.side_effect = [
            25,
            20,
            5,
        ]  # total, regular, admin

        # Mock storage statistics
        mock_storage.get_storage_stats.return_value = {
            "total_analyses": 8,
            "total_size_mb": 15.7,
        }

        result = get_data_statistics()

        expected = {
            "users": {"total": 25, "regular_users": 20, "admins": 5},
            "parking_maps": {"total": 8, "total_size_mb": 15.7},
        }

        assert result == expected

        # Verify correct database queries
        expected_calls = [({"role": "user"},), ({"role": "admin"},)]
        actual_calls = [
            call[0] for call in mock_user_collection.count_documents.call_args_list[1:]
        ]
        for expected_call, actual_call in zip(expected_calls, actual_calls):
            assert actual_call == expected_call

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.storage_manager")
    def test_get_data_statistics_zero_data(self, mock_storage, mock_user_collection):
        """Test data statistics when no data exists"""
        # Mock zero counts
        mock_user_collection.count_documents.side_effect = [0, 0, 0]
        mock_storage.get_storage_stats.return_value = {
            "total_analyses": 0,
            "total_size_mb": 0.0,
        }

        result = get_data_statistics()

        expected = {
            "users": {"total": 0, "regular_users": 0, "admins": 0},
            "parking_maps": {"total": 0, "total_size_mb": 0.0},
        }

        assert result == expected

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.storage_manager")
    def test_get_data_statistics_storage_error(
        self, mock_storage, mock_user_collection
    ):
        """Test data statistics with storage error"""
        mock_user_collection.count_documents.side_effect = [10, 8, 2]
        mock_storage.get_storage_stats.side_effect = Exception(
            "Storage connection error"
        )

        with pytest.raises(HTTPException) as exc_info:
            get_data_statistics()

        assert exc_info.value.status_code == 500
        assert "Failed to retrieve data statistics" in exc_info.value.detail

    @patch("app.admin.router.user_collection")
    def test_get_data_statistics_database_error(self, mock_user_collection):
        """Test data statistics with database error"""
        mock_user_collection.count_documents.side_effect = Exception(
            "Database connection error"
        )

        with pytest.raises(HTTPException) as exc_info:
            get_data_statistics()

        assert exc_info.value.status_code == 500
        assert "Failed to retrieve data statistics" in exc_info.value.detail


class TestAdminClearAllData:
    """Test cases for admin clear all data functionality"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.db")
    @patch("app.admin.router.storage_manager")
    @patch("app.admin.router.metrics")
    def test_clear_all_data_success(
        self, mock_metrics, mock_storage, mock_db, mock_user_collection
    ):
        """Test successful data clearing"""
        # Mock storage stats
        mock_storage.get_storage_stats.return_value = {"total_size_mb": 25.4}

        # Mock database deletion results
        mock_user_collection.delete_many.return_value = MagicMock(deleted_count=15)
        mock_maps_collection = MagicMock()
        mock_maps_collection.delete_many.return_value = MagicMock(deleted_count=8)
        mock_qrcodes_collection = MagicMock()
        mock_qrcodes_collection.delete_many.return_value = MagicMock(deleted_count=3)
        mock_db.maps = mock_maps_collection
        mock_db.qrcodes = mock_qrcodes_collection

        request_data = DataClearRequest(admin_password="123456")

        result = clear_all_test_data(request_data)

        assert result["message"] == "All test data cleared successfully"
        assert result["cleared_data"]["users_deleted"] == 15
        assert result["cleared_data"]["maps_deleted"] == 8
        assert result["cleared_data"]["qrcodes_deleted"] == 3
        assert result["cleared_data"]["storage_cleared_mb"] == 25.4
        assert "Image files in app/examples/images are preserved" in result["note"]

        # Verify all collections were cleared
        mock_user_collection.delete_many.assert_called_once_with({})
        mock_maps_collection.delete_many.assert_called_once_with({})
        mock_qrcodes_collection.delete_many.assert_called_once_with({})

        # Verify metrics
        mock_metrics.increment_counter.assert_called_once_with(
            "AdminOperations", {"operation": "clear_all_data"}
        )

    def test_clear_all_data_invalid_password(self):
        """Test data clearing with invalid admin password"""
        request_data = DataClearRequest(admin_password="wrongpassword")

        with pytest.raises(HTTPException) as exc_info:
            clear_all_test_data(request_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Invalid admin password. Access denied."

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.storage_manager")
    def test_clear_all_data_database_error(self, mock_storage, mock_user_collection):
        """Test data clearing with database error"""
        mock_storage.get_storage_stats.return_value = {"total_size_mb": 10.0}
        mock_user_collection.delete_many.side_effect = Exception(
            "Database connection error"
        )

        request_data = DataClearRequest(admin_password="123456")

        with pytest.raises(HTTPException) as exc_info:
            clear_all_test_data(request_data)

        assert exc_info.value.status_code == 500
        assert "Failed to clear data due to internal error" in exc_info.value.detail

    @patch("app.admin.router.storage_manager")
    def test_clear_all_data_storage_error(self, mock_storage):
        """Test data clearing with storage error"""
        mock_storage.get_storage_stats.side_effect = Exception(
            "Storage connection error"
        )

        request_data = DataClearRequest(admin_password="123456")

        with pytest.raises(HTTPException) as exc_info:
            clear_all_test_data(request_data)

        assert exc_info.value.status_code == 500
        assert "Failed to clear data due to internal error" in exc_info.value.detail


class TestAdminEditParkingRate:
    """Test cases for admin parking rate editing functionality"""

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.parking.utils.load_parking_rates")
    @patch("app.admin.router.save_parking_rates")
    def test_admin_edit_parking_rate_success(
        self, mock_save, mock_load, mock_verify, mock_collection
    ):
        """Test successful parking rate editing"""
        mock_verify.return_value = True
        mock_save.return_value = True

        # Mock admin authentication
        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        # Mock current parking rates
        mock_load.return_value = {
            "currency": "AUD",
            "default_rates": {"base_rate_per_hour": 5.0},
            "destinations": {
                "Westfield Sydney": {
                    "base_rate_per_hour": 6.0,
                    "peak_hour_surcharge_rate": 0.5,
                    "weekend_surcharge_rate": 0.3,
                    "public_holiday_surcharge_rate": 1.0,
                }
            },
        }

        request_data = AdminEditParkingRateRequest(
            destination="westfield sydney",  # Case insensitive
            rates=DestinationRatesRequest(
                base_rate_per_hour="8.0",
                peak_hour_surcharge_rate="-",  # Keep existing
                weekend_surcharge_rate="0.4",
                public_holiday_surcharge_rate="-",
            ),
            keyID="westfield sydney",
            username="admin123",
            password="TestPass123!",
        )

        result = admin_edit_parking_rate(request_data)

        assert result["success"] is True
        assert (
            result["message"]
            == "Parking rates updated successfully for Westfield Sydney"
        )
        assert result["destination"] == "Westfield Sydney"
        assert result["updated_by"] == "admin123"
        assert result["updated_rates"]["base_rate_per_hour"] == 8.0
        assert result["updated_rates"]["peak_hour_surcharge_rate"] == 0.5  # Preserved
        assert result["updated_rates"]["weekend_surcharge_rate"] == 0.4  # Updated
        assert (
            result["updated_rates"]["public_holiday_surcharge_rate"] == 1.0
        )  # Preserved

    @patch("app.admin.router.user_collection")
    def test_admin_edit_parking_rate_invalid_keyid(self, mock_collection):
        """Test parking rate editing with invalid keyID"""
        mock_collection.find_one.return_value = None

        request_data = AdminEditParkingRateRequest(
            destination="Westfield Sydney",
            rates=DestinationRatesRequest(),
            keyID="Invalid KeyID",
            username="admin123",
            password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_parking_rate(request_data)

        assert exc_info.value.status_code == 401
        assert exc_info.value.detail == "Invalid keyID and username combination"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_edit_parking_rate_unauthorized_destination(
        self, mock_verify, mock_collection
    ):
        """Test parking rate editing for unauthorized destination"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",  # Only authorized for Sydney
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        request_data = AdminEditParkingRateRequest(
            destination="Westfield Bondi",  # Different destination
            rates=DestinationRatesRequest(base_rate_per_hour="8.0"),
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_parking_rate(request_data)

        assert exc_info.value.status_code == 403
        assert (
            "not authorize you to edit rates for this destination"
            in exc_info.value.detail
        )

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    def test_admin_edit_parking_rate_empty_destination(
        self, mock_verify, mock_collection
    ):
        """Test parking rate editing with empty destination"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        request_data = AdminEditParkingRateRequest(
            destination="   ",  # Empty destination
            rates=DestinationRatesRequest(base_rate_per_hour="8.0"),
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_parking_rate(request_data)

        assert exc_info.value.status_code == 400
        assert exc_info.value.detail == "Destination name cannot be empty"

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.parking.utils.load_parking_rates")
    def test_admin_edit_parking_rate_invalid_rate_format(
        self, mock_load, mock_verify, mock_collection
    ):
        """Test parking rate editing with invalid rate format"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        mock_load.return_value = {"currency": "AUD", "destinations": {}}

        request_data = AdminEditParkingRateRequest(
            destination="Westfield Sydney",
            rates=DestinationRatesRequest(
                base_rate_per_hour="invalid_number"  # Invalid format
            ),
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_parking_rate(request_data)

        assert exc_info.value.status_code == 400
        assert "must be a valid number or '-'" in exc_info.value.detail

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.parking.utils.load_parking_rates")
    def test_admin_edit_parking_rate_negative_value(
        self, mock_load, mock_verify, mock_collection
    ):
        """Test parking rate editing with negative rate value"""
        mock_verify.return_value = True

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        mock_load.return_value = {"currency": "AUD", "destinations": {}}

        request_data = AdminEditParkingRateRequest(
            destination="Westfield Sydney",
            rates=DestinationRatesRequest(base_rate_per_hour="-5.0"),  # Negative value
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_parking_rate(request_data)

        assert exc_info.value.status_code == 400
        assert "must be non-negative" in exc_info.value.detail

    @patch("app.admin.router.user_collection")
    @patch("app.admin.router.verify_password")
    @patch("app.parking.utils.load_parking_rates")
    @patch("app.admin.router.save_parking_rates")
    def test_admin_edit_parking_rate_save_failure(
        self, mock_save, mock_load, mock_verify, mock_collection
    ):
        """Test parking rate editing with save failure"""
        mock_verify.return_value = True
        mock_save.return_value = False  # Save fails

        admin_doc = {
            "email": "admin@example.com",
            "username": "admin123",
            "password": "$2b$12$hashedpassword",
            "keyID": "Westfield Sydney",
            "role": "admin",
        }
        mock_collection.find_one.return_value = admin_doc

        mock_load.return_value = {
            "currency": "AUD",
            "default_rates": {"base_rate_per_hour": 5.0},
            "destinations": {},
        }

        request_data = AdminEditParkingRateRequest(
            destination="Westfield Sydney",
            rates=DestinationRatesRequest(base_rate_per_hour="8.0"),
            keyID="Westfield Sydney",
            username="admin123",
            password="TestPass123!",
        )

        with pytest.raises(HTTPException) as exc_info:
            admin_edit_parking_rate(request_data)

        assert exc_info.value.status_code == 500
        assert (
            "Failed to save updated parking rates configuration"
            in exc_info.value.detail
        )


class TestParkingRateUtilities:
    """Test cases for parking rate utility functions"""

    def test_normalize_destination_name(self):
        """Test destination name normalization"""
        test_cases = [
            ("westfield sydney", "Westfield Sydney"),
            ("WESTFIELD BONDI JUNCTION", "Westfield Bondi Junction"),
            ("westfield_parramatta", "Westfield Parramatta"),
            ("westfield-chatswood", "Westfield Chatswood"),
            ("  mixed   case_example  ", "Mixed Case Example"),
            ("", ""),
        ]

        for input_name, expected in test_cases:
            result = normalize_destination_name(input_name)
            assert result == expected

    def test_is_admin_authorized_for_destination(self):
        """Test admin authorization for destinations"""
        test_cases = [
            # (keyID, destination, expected_authorized)
            ("Westfield Sydney", "Westfield Sydney", True),
            ("westfield sydney", "Westfield Sydney", True),  # Case insensitive
            ("Westfield", "Westfield Sydney", True),  # Partial match
            ("Sydney", "Westfield Sydney", True),  # Partial match
            ("Westfield Sydney", "Westfield Bondi", False),  # Different location
            ("Unrelated KeyID", "Westfield Sydney", False),  # No match
        ]

        for keyid, destination, expected in test_cases:
            result = is_admin_authorized_for_destination(keyid, destination)
            assert (
                result == expected
            ), f"Failed for keyID='{keyid}', destination='{destination}'"

        # Test empty keyID separately
        result = is_admin_authorized_for_destination("", "Westfield Sydney")
        assert result == False, "Empty keyID should not be authorized"

    def test_parse_rate_value(self):
        """Test rate value parsing"""
        # Test valid cases
        assert parse_rate_value("5.0", "test_rate") == 5.0
        assert parse_rate_value("0", "test_rate") == 0.0
        assert parse_rate_value("-", "test_rate", 10.0) == 10.0  # Keep existing

        # Test invalid cases
        with pytest.raises(ValueError) as exc_info:
            parse_rate_value("invalid", "test_rate")
        assert "must be a valid number or '-'" in str(exc_info.value)

        with pytest.raises(ValueError) as exc_info:
            parse_rate_value("-5.0", "test_rate")
        assert "must be non-negative" in str(exc_info.value)

    @patch("app.parking.utils.save_parking_rates_to_mongodb")
    def test_save_parking_rates_success(self, mock_save_to_mongo):
        """Test successful parking rates saving"""
        mock_save_to_mongo.return_value = True

        rates_config = {"test": "config"}
        result = save_parking_rates(rates_config)

        assert result is True
        mock_save_to_mongo.assert_called_once_with(rates_config)

    @patch("app.parking.utils.save_parking_rates_to_mongodb")
    def test_save_parking_rates_failure(self, mock_save_to_mongo):
        """Test parking rates saving failure"""
        mock_save_to_mongo.return_value = False

        rates_config = {"test": "config"}
        result = save_parking_rates(rates_config)

        assert result is False

    @patch("app.parking.utils.save_parking_rates_to_mongodb")
    def test_save_parking_rates_exception(self, mock_save_to_mongo):
        """Test parking rates saving with exception"""
        mock_save_to_mongo.side_effect = Exception("MongoDB connection error")

        rates_config = {"test": "config"}
        result = save_parking_rates(rates_config)

        assert result is False
