import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
from app.main import app
from datetime import datetime, timezone
from bson import ObjectId
import uuid

client = TestClient(app)


class TestStartSession:
    """Test cases for starting parking sessions"""

    @patch("app.session.router.storage_manager")
    @patch("app.session.router.session_collection")
    @patch("app.session.router.user_collection")
    def test_start_session_success(
        self, mock_user_collection, mock_session_collection, mock_storage_manager
    ):
        """Test successfully starting a parking session"""
        # Mock user data
        mock_user = {"_id": ObjectId(), "username": "testuser", "role": "user"}
        mock_user_collection.find_one.side_effect = [
            mock_user,  # For user verification
        ]

        # Mock no active sessions
        mock_session_collection.find_one.side_effect = [
            None,  # No active user session
            None,  # No active vehicle session
        ]

        # Mock slot info
        mock_slot_info = {"slot": {"slot_id": "A1", "status": "available"}}
        mock_storage_manager.find_slot_by_id.return_value = mock_slot_info

        # Mock database operations
        mock_session_collection.insert_one.return_value = None
        mock_user_collection.update_one.return_value = None
        mock_storage_manager.update_slot_status.return_value = None

        response = client.post(
            "/session/start",
            params={
                "username": "testuser",
                "vehicle_id": "vehicle-123",
                "slot_id": "A1",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["message"] == "Parking session started successfully"
        assert "session" in data
        assert data["session"]["slot_id"] == "A1"
        assert data["session"]["vehicle_id"] == "vehicle-123"
        assert data["session"]["user_id"] == str(mock_user["_id"])

    @patch("app.session.router.user_collection")
    def test_start_session_user_not_found(self, mock_user_collection):
        """Test starting session with non-existent user"""
        mock_user_collection.find_one.return_value = None

        response = client.post(
            "/session/start",
            params={
                "username": "nonexistentuser",
                "vehicle_id": "vehicle-123",
                "slot_id": "A1",
            },
        )

        assert response.status_code == 404
        assert response.json()["detail"] == "User not found"

    @patch("app.session.router.session_collection")
    @patch("app.session.router.user_collection")
    def test_start_session_user_already_has_active_session(
        self, mock_user_collection, mock_session_collection
    ):
        """Test starting session when user already has active session"""
        mock_user = {"_id": ObjectId(), "username": "testuser", "role": "user"}
        mock_user_collection.find_one.return_value = mock_user

        # Mock active session exists
        mock_session_collection.find_one.return_value = {
            "session_id": "existing-session"
        }

        response = client.post(
            "/session/start",
            params={
                "username": "testuser",
                "vehicle_id": "vehicle-123",
                "slot_id": "A1",
            },
        )

        assert response.status_code == 400
        assert response.json()["detail"] == "User already has an active parking session"

    @patch("app.session.router.storage_manager")
    @patch("app.session.router.session_collection")
    @patch("app.session.router.user_collection")
    def test_start_session_allocated_slot_matching_user(
        self, mock_user_collection, mock_session_collection, mock_storage_manager
    ):
        """Test starting session in allocated slot for the correct user"""
        mock_user = {"_id": ObjectId(), "username": "testuser", "role": "user"}
        mock_user_collection.find_one.return_value = mock_user

        # No active sessions
        mock_session_collection.find_one.side_effect = [None, None]

        # Mock allocated slot
        mock_slot_info = {
            "slot": {
                "slot_id": "A1",
                "status": "allocated",
                "reserved_by": "testuser",
                "vehicle_id": "vehicle-123",
            }
        }
        mock_storage_manager.find_slot_by_id.return_value = mock_slot_info

        # Mock database operations
        mock_session_collection.insert_one.return_value = None
        mock_user_collection.update_one.return_value = None
        mock_storage_manager.update_slot_status.return_value = None

        response = client.post(
            "/session/start",
            params={
                "username": "testuser",
                "vehicle_id": "vehicle-123",
                "slot_id": "A1",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True

    @patch("app.session.router.storage_manager")
    @patch("app.session.router.session_collection")
    @patch("app.session.router.user_collection")
    def test_start_session_allocated_slot_wrong_user(
        self, mock_user_collection, mock_session_collection, mock_storage_manager
    ):
        """Test starting session in allocated slot for wrong user"""
        mock_user = {"_id": ObjectId(), "username": "testuser", "role": "user"}
        mock_user_collection.find_one.return_value = mock_user

        # No active sessions
        mock_session_collection.find_one.side_effect = [None, None]

        # Mock allocated slot for different user
        mock_slot_info = {
            "slot": {"slot_id": "A1", "status": "allocated", "reserved_by": "otheruser"}
        }
        mock_storage_manager.find_slot_by_id.return_value = mock_slot_info

        response = client.post(
            "/session/start",
            params={
                "username": "testuser",
                "vehicle_id": "vehicle-123",
                "slot_id": "A1",
            },
        )

        assert response.status_code == 403
        assert "allocated to a different user" in response.json()["detail"]


class TestEndSession:
    """Test cases for ending parking sessions"""

    @patch("app.session.router.storage_manager")
    @patch("app.session.router.session_collection")
    @patch("app.session.router.user_collection")
    def test_end_session_success(
        self, mock_user_collection, mock_session_collection, mock_storage_manager
    ):
        """Test successfully ending a parking session"""
        user_id = ObjectId()
        mock_user = {"_id": user_id, "username": "testuser", "role": "user"}
        mock_user_collection.find_one.return_value = mock_user

        # Mock active session
        mock_session = {
            "session_id": "session-123",
            "slot_id": "A1",
            "user_id": str(user_id),
            "vehicle_id": "vehicle-123",
            "start_time": datetime.now(timezone.utc),
            "end_time": None,
        }
        mock_session_collection.find_one.side_effect = [
            mock_session,  # For finding active session
            {**mock_session, "end_time": datetime.now(timezone.utc)},  # Updated session
        ]

        # Mock database operations
        mock_session_collection.update_one.return_value = None
        mock_user_collection.update_one.return_value = None
        mock_storage_manager.update_slot_status.return_value = None

        response = client.post(
            "/session/end", params={"username": "testuser", "vehicle_id": "vehicle-123"}
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "ended successfully" in data["message"]
        assert data["session"]["end_time"] is not None

    @patch("app.session.router.session_collection")
    @patch("app.session.router.user_collection")
    def test_end_session_no_active_session(
        self, mock_user_collection, mock_session_collection
    ):
        """Test ending session when no active session exists"""
        mock_user = {"_id": ObjectId(), "username": "testuser", "role": "user"}
        mock_user_collection.find_one.return_value = mock_user

        # No active session found
        mock_session_collection.find_one.return_value = None

        response = client.post(
            "/session/end", params={"username": "testuser", "vehicle_id": "vehicle-123"}
        )

        assert response.status_code == 404
        assert "No active parking session found" in response.json()["detail"]

    @patch("app.session.router.storage_manager")
    @patch("app.session.router.session_collection")
    @patch("app.session.router.user_collection")
    def test_end_session_with_session_id(
        self, mock_user_collection, mock_session_collection, mock_storage_manager
    ):
        """Test ending session with specific session ID"""
        user_id = ObjectId()
        mock_user = {"_id": user_id, "username": "testuser", "role": "user"}
        mock_user_collection.find_one.return_value = mock_user

        # Mock session
        mock_session = {
            "session_id": "session-123",
            "slot_id": "A1",
            "user_id": str(user_id),
            "vehicle_id": "vehicle-123",
        }
        mock_session_collection.find_one.side_effect = [
            mock_session,
            {**mock_session, "end_time": datetime.now(timezone.utc)},
        ]

        # Mock database operations
        mock_session_collection.update_one.return_value = None
        mock_user_collection.update_one.return_value = None
        mock_storage_manager.update_slot_status.return_value = None

        response = client.post(
            "/session/end",
            params={
                "username": "testuser",
                "vehicle_id": "vehicle-123",
                "session_id": "session-123",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True


class TestGetActiveSession:
    """Test cases for getting active parking sessions"""

    @patch("app.session.router.session_collection")
    @patch("app.session.router.user_collection")
    def test_get_active_session_by_username(
        self, mock_user_collection, mock_session_collection
    ):
        """Test getting active session by username"""
        user_id = ObjectId()
        mock_user = {"_id": user_id, "username": "testuser", "role": "user"}
        mock_user_collection.find_one.return_value = mock_user

        # Mock active session
        mock_session = {
            "_id": ObjectId(),
            "session_id": "session-123",
            "slot_id": "A1",
            "user_id": str(user_id),
            "vehicle_id": "vehicle-123",
            "start_time": datetime.now(timezone.utc),
            "end_time": None,
        }
        mock_session_collection.find_one.return_value = mock_session

        response = client.get("/session/active", params={"username": "testuser"})

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["session"]["session_id"] == "session-123"
        assert "_id" not in data["session"]

    @patch("app.session.router.session_collection")
    def test_get_active_session_by_vehicle(self, mock_session_collection):
        """Test getting active session by vehicle ID"""
        # Mock active session
        mock_session = {
            "_id": ObjectId(),
            "session_id": "session-123",
            "slot_id": "A1",
            "user_id": "user-456",
            "vehicle_id": "vehicle-123",
            "start_time": datetime.now(timezone.utc),
            "end_time": None,
        }
        mock_session_collection.find_one.return_value = mock_session

        response = client.get("/session/active", params={"vehicle_id": "vehicle-123"})

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["session"]["vehicle_id"] == "vehicle-123"

    def test_get_active_session_no_params(self):
        """Test getting active session without parameters"""
        response = client.get("/session/active")

        assert response.status_code == 400
        assert (
            "Either username or vehicle_id must be provided"
            in response.json()["detail"]
        )

    @patch("app.session.router.session_collection")
    @patch("app.session.router.user_collection")
    def test_get_active_session_not_found(
        self, mock_user_collection, mock_session_collection
    ):
        """Test getting active session when none exists"""
        mock_user = {"_id": ObjectId(), "username": "testuser", "role": "user"}
        mock_user_collection.find_one.return_value = mock_user

        # No active session
        mock_session_collection.find_one.return_value = None

        response = client.get("/session/active", params={"username": "testuser"})

        assert response.status_code == 404
        assert "No active parking session found" in response.json()["detail"]


class TestGetActiveSessionsByBuilding:
    """Test cases for getting active sessions by building"""

    @patch("app.session.router.session_collection")
    @patch("app.session.router.user_collection")
    @patch("app.session.router.storage_manager")
    def test_get_active_sessions_by_building_success(
        self, mock_storage_manager, mock_user_collection, mock_session_collection
    ):
        """Test getting active sessions for a building"""
        # Mock building slots
        mock_slots = [{"slot_id": "A1"}, {"slot_id": "A2"}, {"slot_id": "B1"}]
        mock_storage_manager.get_slots_by_criteria.return_value = mock_slots

        # Mock active sessions
        user_id = ObjectId()
        mock_sessions = [
            {
                "_id": ObjectId(),
                "session_id": "session-1",
                "slot_id": "A1",
                "user_id": str(user_id),
                "vehicle_id": "vehicle-123",
                "start_time": datetime.now(timezone.utc),
                "end_time": None,
            }
        ]
        mock_session_collection.find.return_value = mock_sessions

        # Mock user lookup
        mock_user_collection.find_one.return_value = {
            "_id": user_id,
            "username": "testuser",
        }

        response = client.get(
            "/session/active-sessions-by-building",
            params={"building_name": "Westfield Sydney"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["building_name"] == "Westfield Sydney"
        assert data["total_active_sessions"] == 1
        assert len(data["sessions_by_user"]) == 1
        assert data["sessions_by_user"][0]["username"] == "testuser"

    def test_get_active_sessions_by_building_no_building_name(self):
        """Test getting active sessions without building name"""
        response = client.get("/session/active-sessions-by-building", params={})

        assert response.status_code == 422  # FastAPI validation error

    @patch("app.session.router.storage_manager")
    def test_get_active_sessions_building_not_found(self, mock_storage_manager):
        """Test getting active sessions for non-existent building"""
        mock_storage_manager.get_slots_by_criteria.return_value = []

        response = client.get(
            "/session/active-sessions-by-building",
            params={"building_name": "NonExistentBuilding"},
        )

        assert response.status_code == 404
        assert response.json()["detail"] == "Building not found"


class TestGetSessionHistory:
    """Test cases for getting session history"""

    @patch("app.session.router.session_collection")
    @patch("app.session.router.user_collection")
    def test_get_session_history_success(
        self, mock_user_collection, mock_session_collection
    ):
        """Test getting session history for a user"""
        user_id = ObjectId()
        mock_user = {"_id": user_id, "username": "testuser", "role": "user"}
        mock_user_collection.find_one.return_value = mock_user

        # Mock session history
        mock_sessions = [
            {
                "_id": ObjectId(),
                "session_id": "session-1",
                "slot_id": "A1",
                "user_id": str(user_id),
                "vehicle_id": "vehicle-123",
                "start_time": datetime.now(timezone.utc),
                "end_time": datetime.now(timezone.utc),
            },
            {
                "_id": ObjectId(),
                "session_id": "session-2",
                "slot_id": "B1",
                "user_id": str(user_id),
                "vehicle_id": "vehicle-456",
                "start_time": datetime.now(timezone.utc),
                "end_time": None,
            },
        ]

        # Mock MongoDB cursor methods
        mock_cursor = MagicMock()
        mock_cursor.sort.return_value = mock_cursor
        mock_cursor.limit.return_value = mock_sessions
        mock_session_collection.find.return_value = mock_cursor

        # Mock count
        mock_session_collection.count_documents.return_value = 2

        response = client.get(
            "/session/history", params={"username": "testuser", "limit": 10}
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["total_sessions"] == 2
        assert len(data["sessions"]) == 2
        assert "_id" not in data["sessions"][0]

    @patch("app.session.router.user_collection")
    def test_get_session_history_user_not_found(self, mock_user_collection):
        """Test getting session history for non-existent user"""
        mock_user_collection.find_one.return_value = None

        response = client.get(
            "/session/history", params={"username": "nonexistentuser"}
        )

        assert response.status_code == 404
        assert response.json()["detail"] == "User not found"

    def test_get_session_history_invalid_limit(self):
        """Test getting session history with invalid limit"""
        response = client.get(
            "/session/history", params={"username": "testuser", "limit": 101}
        )

        assert response.status_code == 422  # FastAPI validation error
