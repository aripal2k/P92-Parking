import pytest
import mongomock
import sys
import os
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
import time

# test configuration file for pytest
# Add the Backend directory to Python path (for importing app modules)
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.main import app
from app.auth.auth import (
    UserCreate,
    UserLogin,
    ChangePasswordRequest,
    ForgotPasswordRequest,
)
from app.auth.utils import hash_password


# Mock MongoDB for testing
@pytest.fixture
def mock_user_collection():
    """Mock MongoDB user collection using mongomock"""
    mock_client = mongomock.MongoClient()
    mock_db = mock_client["test_parking_app"]
    return mock_db["users"]


@pytest.fixture
def client():
    """FastAPI test client"""
    return TestClient(app)


@pytest.fixture
def sample_user_data():
    """Sample user data for testing"""
    return {
        "fullname": "Test User",
        "email": "test@example.com",
        "username": "testuser",
        "password": "TestPass123!",
        "confirm_password": "TestPass123!",
    }


@pytest.fixture
def sample_user_create(sample_user_data):
    """Sample UserCreate object"""
    return UserCreate(**sample_user_data)


@pytest.fixture
def sample_login_data():
    """Sample login data"""
    return {"email": "test@example.com", "password": "TestPass123!"}


@pytest.fixture
def sample_user_login(sample_login_data):
    """Sample UserLogin object"""
    return UserLogin(**sample_login_data)


@pytest.fixture
def registered_user(mock_user_collection):
    """A pre-registered user in the mock database"""
    user_data = {
        "_id": "test_user_id",
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
    }
    mock_user_collection.insert_one(user_data)
    return user_data


@pytest.fixture
def mock_email_sending():
    """Mock email sending functionality"""
    with patch("app.auth.router.send_email_otp") as mock_send:
        mock_send.return_value = None
        yield mock_send


@pytest.fixture
def mock_time():
    """Mock time.time() for consistent testing"""
    with patch("time.time") as mock:
        mock.return_value = 1640995200.0  # fixed timestamp
        yield mock


@pytest.fixture
def mock_generate_otp():
    """Mock OTP generation for predictable testing"""
    with patch("app.auth.router.generate_otp") as mock:
        mock.return_value = "123456"
        yield mock


@pytest.fixture
def mock_metrics():
    """Mock CloudWatch metrics"""
    with patch("app.auth.router.metrics") as mock:
        mock.record_auth_event = MagicMock()
        yield mock


@pytest.fixture(autouse=True)
def mock_database():
    """Auto-use fixture to mock the database connection"""
    with patch("app.auth.router.user_collection") as mock_collection:
        # Use mongomock for consistent behavior
        mock_client = mongomock.MongoClient()
        mock_db = mock_client["test_parking_app"]
        mock_collection.return_value = mock_db["users"]
        yield mock_db["users"]


@pytest.fixture
def invalid_passwords():
    """Collection of invalid passwords for testing"""
    return [
        "short",  # Too short
        "nouppercase123!",  # No uppercase
        "NOLOWERCASE123!",  # No lowercase
        "NoNumbers!",  # No numbers
        "NoSpecialChars123",  # No special characters
        "password123!",  # Too common
        "123456789!",  # Too common
    ]


@pytest.fixture
def change_password_data():
    """Sample change password data"""
    return {
        "email": "test@example.com",
        "current_password": "TestPass123!",
        "new_password": "NewPass456@",
        "confirm_new_password": "NewPass456@",
    }


@pytest.fixture
def forgot_password_data():
    """Sample forgot password data"""
    return {"email": "test@example.com"}


# Admin fixtures
@pytest.fixture
def sample_admin_register_data():
    """Sample admin registration data"""
    return {"email": "admin@example.com", "keyID": "Westfield Sydney"}


@pytest.fixture
def sample_admin_login_data():
    """Sample admin login data"""
    return {
        "keyID": "Westfield Sydney",
        "username": "admin123",
        "password": "AdminPass123!",
        "email": "admin@example.com",
    }


@pytest.fixture
def sample_admin_edit_data():
    """Sample admin edit profile data"""
    return {
        "keyID": "Westfield Sydney",
        "current_username": "admin123",
        "current_password": "AdminPass123!",
        "new_username": "new_admin123",
    }


@pytest.fixture
def sample_admin_change_password_data():
    """Sample admin change password data"""
    return {
        "keyID": "Westfield Sydney",
        "current_username": "admin123",
        "current_password": "AdminPass123!",
        "new_password": "NewAdminPass456@",
        "confirm_new_password": "NewAdminPass456@",
    }


@pytest.fixture
def sample_parking_rate_data():
    """Sample parking rate edit data"""
    return {
        "destination": "Westfield Sydney",
        "rates": {
            "base_rate_per_hour": "8.0",
            "peak_hour_surcharge_rate": "0.6",
            "weekend_surcharge_rate": "0.4",
            "public_holiday_surcharge_rate": "1.2",
        },
        "keyID": "Westfield Sydney",
        "username": "admin123",
        "password": "AdminPass123!",
    }


@pytest.fixture
def sample_slot_update_data():
    """Sample slot status update data"""
    return {
        "slot_id": "A1",
        "new_status": "occupied",
        "vehicle_id": "NSW123",
        "reserved_by": "user123",
        "keyID": "Westfield Sydney",
        "username": "admin123",
        "password": "AdminPass123!",
        "building_name": "Westfield Sydney",
        "level": 1,
    }


@pytest.fixture
def registered_admin(mock_user_collection):
    """A pre-registered admin in the mock database"""
    admin_data = {
        "_id": "test_admin_id",
        "email": "admin@example.com",
        "username": "admin123",
        "keyID": "Westfield Sydney",
        "password": "$2b$12$hashedpassword",  # Hashed password
        "role": "admin",
    }
    mock_user_collection.insert_one(admin_data)
    return admin_data


###
@pytest.fixture
def mock_admin_metrics():
    """Mock CloudWatch metrics for admin operations"""
    with patch("app.admin.router.metrics") as mock:
        mock.record_auth_event = MagicMock()
        mock.increment_counter = MagicMock()
        yield mock


@pytest.fixture
def mock_storage_manager():
    """Mock storage manager for parking operations"""
    with patch("app.admin.router.storage_manager") as mock:
        mock.find_slot_by_id.return_value = None
        mock.update_slot_status.return_value = True
        mock.get_storage_stats.return_value = {
            "total_analyses": 0,
            "total_size_mb": 0.0,
        }
        yield mock


@pytest.fixture
def mock_parking_rates():
    """Mock parking rates configuration"""
    return {
        "currency": "AUD",
        "default_rates": {
            "base_rate_per_hour": 5.0,
            "peak_hour_surcharge_rate": 0.5,
            "weekend_surcharge_rate": 0.3,
            "public_holiday_surcharge_rate": 1.0,
        },
        "peak_hours": {"start": "07:00", "end": "19:00"},
        "public_holidays": ["2023-01-01", "2023-04-07"],
        "destinations": {
            "Westfield Sydney": {
                "base_rate_per_hour": 6.0,
                "peak_hour_surcharge_rate": 0.6,
                "weekend_surcharge_rate": 0.4,
                "public_holiday_surcharge_rate": 1.2,
            }
        },
    }


@pytest.fixture
def mock_slot_info():
    """Mock parking slot information"""
    return {
        "slot": {
            "slot_id": "A1",
            "status": "available",
            "x": 100,
            "y": 150,
            "vehicle_id": None,
            "reserved_by": None,
        },
        "map_id": "map123",
        "building_name": "Westfield Sydney",
        "level": 1,
    }


# Admin test


@pytest.fixture
def mock_admin_user():
    """Sample admin user data for testing"""
    return {
        "email": "admin@example.com",
        "username": "admin123",
        "password": "$2b$12$hashedpassword",
        "keyID": "Westfield Sydney",
        "role": "admin",
    }


@pytest.fixture
def mock_regular_user_for_reservation():
    """Sample regular user data for slot reservation testing"""
    return {
        "username": "user123",
        "email": "user123@example.com",
        "role": "user",
        "fullname": "Test User",
    }


@pytest.fixture
def mock_admin_database_queries(mock_admin_user, mock_regular_user_for_reservation):
    """Centralized mock for admin database queries including user validation"""

    def mock_find_one(query):
        # Handle admin authentication queries (keyID + username + role)
        if "keyID" in query and "username" in query and "role" in query:
            if (
                query.get("username") == mock_admin_user["username"]
                and query.get("role") == "admin"
            ):
                return mock_admin_user

        # Handle user validation queries for reserved_by (username + role=user)
        elif "username" in query and query.get("role") == "user":
            if query["username"] == "user123":
                return mock_regular_user_for_reservation
            elif query["username"] == "user1":  # For concurrent test
                return {"username": "user1", "role": "user"}
            elif query["username"] == "user2":  # For concurrent test
                return {"username": "user2", "role": "user"}

        # Handle legacy admin queries (just keyID with regex)
        elif "keyID" in query and "$regex" in query.get("keyID", {}):
            return mock_admin_user

        return None

    return mock_find_one


@pytest.fixture(autouse=True)
def mock_database_user_collection_for_admin_tests(mock_admin_database_queries):
    """Auto-use fixture to mock database user_collection for AdminSlotStatusUpdate validation"""
    with patch("app.database.user_collection") as mock_db_collection:
        mock_db_collection.find_one.side_effect = mock_admin_database_queries
        yield mock_db_collection
