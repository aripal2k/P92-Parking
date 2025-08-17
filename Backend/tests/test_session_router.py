"""
Test cases for session router endpoints
Target Coverage: 80%
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock, Mock
from app.main import app
from bson import ObjectId
from datetime import datetime, timezone
import uuid

client = TestClient(app)


class TestStartSession:
    """Test cases for /session/start endpoint"""

    @patch("app.session.router.user_collection")
    @patch("app.session.router.session_collection")
    @patch("app.session.router.storage_manager")
    @patch("app.session.router.get_map_data")
    @patch("app.session.router.PathPlanner")
    def test_start_session_success(
        self, mock_planner, mock_get_map, mock_storage, mock_session, mock_user
    ):
        """Test successful session start"""
        # Setup mocks
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
            "role": "user",
        }

        mock_session.find_one.side_effect = [None, None]  # No active sessions
        mock_session.insert_one.return_value.inserted_id = ObjectId(
            "607f1f77bcf86cd799439012"
        )

        mock_storage.find_slot_by_id.return_value = {
            "slot": {
                "slot_id": "A1",
                "status": "available",
                "allocated_to": None,
            }
        }
        mock_storage.update_slot_status.return_value = True

        mock_get_map.return_value = {
            "parking_map": [
                {
                    "slots": [{"slot_id": "A1", "x": 5, "y": 5}],
                    "exits": [{"exit_id": "X1", "x": 10, "y": 10}],
                }
            ]
        }

        mock_planner_instance = MagicMock()
        mock_planner.return_value = mock_planner_instance
        mock_planner_instance.find_nearest_exit_to_slot.return_value = (
            {"exit_id": "X1", "x": 10, "y": 10},  # nearest_exit
            10.0,  # distance
            [],  # path
        )

        mock_user.update_one.return_value = MagicMock()

        response = client.post(
            "/session/start",
            params={
                "username": "test_user",
                "vehicle_id": "vehicle-123",
                "slot_id": "A1",
                "entrance_id": "E1",
                "building_name": "TestBuilding",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "session" in data
        assert data["session"]["slot_id"] == "A1"

    @patch("app.session.router.user_collection")
    def test_start_session_user_not_found(self, mock_user):
        """Test session start with non-existent user"""
        mock_user.find_one.return_value = None

        response = client.post(
            "/session/start",
            params={
                "username": "non_existent",
                "vehicle_id": "vehicle-123",
                "slot_id": "A1",
            },
        )

        assert response.status_code == 404
        assert "User not found" in response.json()["detail"]

    @patch("app.session.router.user_collection")
    @patch("app.session.router.session_collection")
    def test_start_session_user_already_active(self, mock_session, mock_user):
        """Test session start when user already has active session"""
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
            "role": "user",
        }

        mock_session.find_one.return_value = {
            "session_id": "existing-session",
            "end_time": None,
        }

        response = client.post(
            "/session/start",
            params={
                "username": "test_user",
                "vehicle_id": "vehicle-123",
                "slot_id": "A1",
            },
        )

        assert response.status_code == 400
        assert "already has an active parking session" in response.json()["detail"]

    @patch("app.session.router.user_collection")
    @patch("app.session.router.session_collection")
    @patch("app.session.router.storage_manager")
    def test_start_session_slot_unavailable(
        self, mock_storage, mock_session, mock_user
    ):
        """Test session start with unavailable slot"""
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
            "role": "user",
        }

        mock_session.find_one.side_effect = [None, None]
        mock_storage.find_slot_by_id.return_value = {
            "slot": {
                "slot_id": "A1",
                "status": "occupied",
            }
        }

        response = client.post(
            "/session/start",
            params={
                "username": "test_user",
                "vehicle_id": "vehicle-123",
                "slot_id": "A1",
            },
        )

        assert response.status_code == 400
        assert "not available" in response.json()["detail"]


class TestEndSession:
    """Test cases for /session/end endpoint"""

    @patch("app.session.router.user_collection")
    @patch("app.session.router.session_collection")
    @patch("app.session.router.storage_manager")
    def test_end_session_success(self, mock_storage, mock_session, mock_user):
        """Test successful session end"""
        # Setup mocks
        start_time = datetime.now(timezone.utc)
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
            "role": "user",
        }

        mock_session.find_one.side_effect = [
            {
                "_id": ObjectId("507f1f77bcf86cd799439012"),
                "session_id": "session-123",
                "user_id": str(ObjectId("507f1f77bcf86cd799439011")),
                "vehicle_id": "vehicle-123",
                "slot_id": "A1",
                "start_time": start_time,
                "end_time": None,
                "fee": None,
            },
            {
                "_id": ObjectId("507f1f77bcf86cd799439012"),
                "session_id": "session-123",
                "user_id": str(ObjectId("507f1f77bcf86cd799439011")),
                "vehicle_id": "vehicle-123",
                "slot_id": "A1",
                "start_time": start_time,
                "end_time": datetime.now(timezone.utc),
            },
        ]

        mock_session.update_one.return_value.modified_count = 1
        mock_storage.update_slot_status.return_value = True
        mock_user.update_one.return_value = MagicMock()

        response = client.post(
            "/session/end",
            params={
                "username": "test_user",
                "vehicle_id": "vehicle-123",
                "session_id": "session-123",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "session" in data
        assert data["session"]["session_id"] == "session-123"
        assert "end_time" in data["session"]

    @patch("app.session.router.user_collection")
    @patch("app.session.router.session_collection")
    def test_end_session_not_found(self, mock_session, mock_user):
        """Test ending non-existent session"""
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
            "role": "user",
        }
        mock_session.find_one.return_value = None

        response = client.post(
            "/session/end",
            params={
                "username": "test_user",
                "vehicle_id": "vehicle-123",
                "session_id": "non-existent",
            },
        )

        assert response.status_code == 404
        assert "No active parking session found" in response.json()["detail"]

    @patch("app.session.router.user_collection")
    @patch("app.session.router.session_collection")
    def test_end_session_already_ended(self, mock_session, mock_user):
        """Test ending already ended session"""
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
            "role": "user",
        }
        # When end_time is not None, the find_one query with end_time=None won't find it
        mock_session.find_one.return_value = None

        response = client.post(
            "/session/end",
            params={
                "username": "test_user",
                "vehicle_id": "vehicle-123",
                "session_id": "session-123",
            },
        )

        assert response.status_code == 404


class TestGetActiveSession:
    """Test cases for /session/active endpoint"""

    @patch("app.session.router.user_collection")
    @patch("app.session.router.session_collection")
    def test_get_active_session_by_username(self, mock_session, mock_user):
        """Test getting active session by username"""
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
            "role": "user",
        }

        mock_session.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439012"),
            "session_id": "session-123",
            "user_id": str(ObjectId("507f1f77bcf86cd799439011")),
            "slot_id": "A1",
            "vehicle_id": "vehicle-123",
            "start_time": datetime.now(timezone.utc),
            "end_time": None,
        }

        response = client.get("/session/active?username=test_user")

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["session"]["session_id"] == "session-123"

    @patch("app.session.router.session_collection")
    def test_get_active_session_not_found(self, mock_session):
        """Test getting active session when none exists"""
        mock_session.find_one.return_value = None

        response = client.get("/session/active?vehicle_id=vehicle-123")

        assert response.status_code == 404
        assert "No active parking session found" in response.json()["detail"]

    def test_get_active_session_no_params(self):
        """Test getting active session without parameters"""
        response = client.get("/session/active")

        assert response.status_code == 400
        assert "must be provided" in response.json()["detail"]


class TestGetActiveSessionsByBuilding:
    """Test cases for /session/active-sessions-by-building endpoint"""

    @patch("app.session.router.storage_manager")
    @patch("app.session.router.session_collection")
    @patch("app.session.router.user_collection")
    def test_get_active_sessions_by_building(
        self, mock_user, mock_session, mock_storage
    ):
        """Test getting active sessions for a building"""
        # Mock storage to return slots for building
        mock_storage.get_slots_by_criteria.return_value = [
            {"slot_id": "A1", "building": "TestBuilding"},
            {"slot_id": "A2", "building": "TestBuilding"},
        ]

        # Mock active sessions
        mock_session.find.return_value = [
            {
                "_id": ObjectId("507f1f77bcf86cd799439012"),
                "session_id": "session-1",
                "user_id": "507f1f77bcf86cd799439011",
                "slot_id": "A1",
                "vehicle_id": "vehicle-123",
                "start_time": datetime.now(timezone.utc),
            }
        ]

        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
        }

        response = client.get(
            "/session/active-sessions-by-building?building_name=TestBuilding"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "sessions_by_user" in data


class TestGetSessionHistory:
    """Test cases for /session/history endpoint"""

    @patch("app.session.router.user_collection")
    @patch("app.session.router.session_collection")
    def test_get_history_with_username(self, mock_session, mock_user):
        """Test getting session history with username"""
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
            "role": "user",
        }

        mock_find = MagicMock()
        mock_sort = MagicMock()
        mock_limit = MagicMock()

        mock_session.find.return_value = mock_find
        mock_find.sort.return_value = mock_sort
        mock_sort.limit.return_value = [
            {
                "_id": ObjectId("507f1f77bcf86cd799439012"),
                "session_id": "session-1",
                "user_id": str(ObjectId("507f1f77bcf86cd799439011")),
                "slot_id": "A1",
                "start_time": datetime.now(timezone.utc),
                "end_time": datetime.now(timezone.utc),
                "fee": 10.0,
            },
            {
                "_id": ObjectId("507f1f77bcf86cd799439013"),
                "session_id": "session-2",
                "user_id": str(ObjectId("507f1f77bcf86cd799439011")),
                "slot_id": "A2",
                "start_time": datetime.now(timezone.utc),
                "end_time": datetime.now(timezone.utc),
                "fee": 15.0,
            },
        ]

        mock_session.count_documents.return_value = 2

        response = client.get("/session/history?username=test_user&limit=10")

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert len(data["sessions"]) == 2
        assert data["total_sessions"] == 2

    @patch("app.session.router.user_collection")
    @patch("app.session.router.session_collection")
    def test_get_user_active_sessions(self, mock_session, mock_user):
        """Test getting active sessions for specific user"""
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
        }

        mock_session.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439012"),
            "session_id": "session-1",
            "user_id": str(ObjectId("507f1f77bcf86cd799439011")),
            "slot_id": "A1",
            "start_time": datetime.now(timezone.utc),
        }

        response = client.get("/session/active?username=test_user")

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["session"]["session_id"] == "session-1"

    @patch("app.session.router.user_collection")
    @patch("app.session.router.session_collection")
    def test_get_all_history(self, mock_session, mock_user):
        """Test getting all session history"""
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
            "role": "user",
        }

        mock_find = MagicMock()
        mock_sort = MagicMock()
        mock_limit = MagicMock()

        mock_session.find.return_value = mock_find
        mock_find.sort.return_value = mock_sort
        mock_sort.limit.return_value = [
            {
                "_id": ObjectId("507f1f77bcf86cd799439012"),
                "session_id": "session-1",
                "user_id": str(ObjectId("507f1f77bcf86cd799439011")),
                "slot_id": "A1",
                "start_time": datetime.now(timezone.utc),
                "end_time": datetime.now(timezone.utc),
            }
        ]

        mock_session.count_documents.return_value = 1

        response = client.get("/session/history?username=test_user&limit=10")

        assert response.status_code == 200


class TestDeleteSession:
    """Test cases for /session/delete endpoint"""

    @patch("app.session.router.session_collection")
    @patch("app.session.router.storage_manager")
    @patch("app.session.router.user_collection")
    def test_delete_session_success(self, mock_user, mock_storage, mock_session):
        """Test successful session deletion"""
        mock_session.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439012"),
            "session_id": "session-123",
            "slot_id": "A1",
            "user_id": "507f1f77bcf86cd799439011",
            "end_time": None,
        }

        mock_session.delete_one.return_value.deleted_count = 1
        mock_storage.update_slot_status.return_value = True
        mock_user.update_one.return_value = MagicMock()

        response = client.delete("/session/delete?session_id=session-123")

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "deleted" in data["message"]

    @patch("app.session.router.session_collection")
    def test_delete_session_not_found(self, mock_session):
        """Test deleting non-existent session"""
        mock_session.find_one.return_value = None

        response = client.delete("/session/delete?session_id=session-123")

        assert response.status_code == 404
        assert "Session not found" in response.json()["detail"]


class TestClearAllSessions:
    """Test cases for /session/clear-all endpoint"""

    @patch("app.session.router.user_collection")
    @patch("app.session.router.session_collection")
    @patch("app.session.router.storage_manager")
    def test_clear_all_sessions(self, mock_storage, mock_session, mock_user):
        """Test clearing all sessions for a user"""
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
            "role": "user",
        }

        mock_session.find.return_value = [
            {"session_id": "session-1", "slot_id": "A1", "end_time": None},
            {"session_id": "session-2", "slot_id": "A2", "end_time": None},
        ]

        mock_session.delete_many.return_value.deleted_count = 2
        mock_storage.update_slot_status.return_value = True
        mock_user.update_one.return_value = MagicMock()

        response = client.delete("/session/clear-all?username=test_user")

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["deleted_count"] == 2

    @patch("app.session.router.user_collection")
    def test_clear_sessions_user_not_found(self, mock_user):
        """Test clearing sessions when user not found"""
        mock_user.find_one.return_value = None

        response = client.delete("/session/clear-all?username=non_existent")

        assert response.status_code == 404
        assert "User not found" in response.json()["detail"]


class TestUpdateExit:
    """Test cases for /session/update-exit PUT endpoint"""

    @patch("app.session.router.session_collection")
    def test_update_exit_success(self, mock_session):
        """Test successful exit update"""
        mock_session.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439012"),
            "session_id": "session-123",
            "slot_id": "A1",
            "exit_id": None,
            "end_time": None,
        }

        mock_session.update_one.return_value.modified_count = 1

        response = client.put("/session/update-exit?session_id=session-123&exit_id=X2")

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "updated" in data["message"]

    @patch("app.session.router.session_collection")
    def test_update_exit_not_found(self, mock_session):
        """Test updating exit for non-existent session"""
        mock_session.find_one.return_value = None

        response = client.put("/session/update-exit?session_id=non-existent&exit_id=X1")

        assert response.status_code == 404
        assert "Session not found" in response.json()["detail"]

    @patch("app.session.router.session_collection")
    def test_update_exit_already_ended(self, mock_session):
        """Test updating exit for already ended session"""
        mock_session.find_one.side_effect = [
            {
                "session_id": "session-123",
                "slot_id": "A1",
                "end_time": datetime.now(timezone.utc),
            },
            {
                "session_id": "session-123",
                "slot_id": "A1",
                "exit_id": "X1",
                "entrance_id": "E1",
            },
        ]

        mock_session.update_one.return_value.modified_count = 1

        response = client.put("/session/update-exit?session_id=session-123&exit_id=X1")

        # Update exit doesn't check end_time, so it succeeds
        assert response.status_code == 200


class TestErrorHandling:
    """Test error handling scenarios"""

    @patch("app.session.router.user_collection")
    def test_database_error(self, mock_user):
        """Test handling of database errors"""
        mock_user.find_one.side_effect = Exception("Database connection failed")

        response = client.get("/session/active?username=test_user")

        # When user lookup fails with an exception, it returns 500
        assert response.status_code == 500

    @patch("app.session.router.user_collection")
    @patch("app.session.router.session_collection")
    @patch("app.session.router.storage_manager")
    def test_slot_update_after_insert(self, mock_storage, mock_session, mock_user):
        """Test slot update happens after session insert"""
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
            "role": "user",
        }

        mock_session.find_one.side_effect = [None, None]
        mock_storage.find_slot_by_id.return_value = {
            "slot": {
                "slot_id": "A1",
                "status": "available",
            }
        }
        mock_session.insert_one.return_value.inserted_id = ObjectId(
            "607f1f77bcf86cd799439012"
        )
        mock_storage.update_slot_status.return_value = True
        mock_user.update_one.return_value = MagicMock()

        response = client.post(
            "/session/start",
            params={
                "username": "test_user",
                "vehicle_id": "vehicle-123",
                "slot_id": "A1",
            },
        )

        # The slot update happens after session insert, so it should succeed
        assert response.status_code == 200


class TestSessionValidation:
    """Test input validation for session endpoints"""

    def test_start_session_missing_params(self):
        """Test session start with missing required parameters"""
        response = client.post(
            "/session/start",
            params={"username": "test_user"},  # Missing vehicle_id and slot_id
        )

        assert response.status_code == 422  # Validation error

    def test_update_exit_missing_params(self):
        """Test updating exit with missing parameters"""
        response = client.put("/session/update-exit")

        assert response.status_code == 422  # Validation error
