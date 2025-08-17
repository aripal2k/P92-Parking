"""
Test cases for emissions router endpoints
Target Coverage: 60%
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock, Mock
from app.main import app
from bson import ObjectId

client = TestClient(app)


class TestEstimateEmissions:
    """Test cases for /emissions/estimate endpoint"""

    @patch("app.emissions.router.emission_storage")
    def test_estimate_emissions_success(self, mock_storage):
        """Test successful emissions estimation"""
        mock_storage.store_emission_record.return_value = "record-123"

        response = client.get(
            "/emissions/estimate",
            params={
                "route_distance": 50.0,
                "baseline_distance": 150.0,
                "emissions_factor": 0.194,
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "emissions_saved" in data
        assert "percentage_saved" in data
        assert "message" in data
        assert data["actual_distance"] == 50.0

    def test_estimate_emissions_default_values(self):
        """Test emissions estimation with default values"""
        response = client.get("/emissions/estimate", params={"route_distance": 30.0})

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["actual_distance"] == 30.0
        assert "baseline_distance" in data
        assert "emissions_factor" in data

    def test_estimate_emissions_invalid_distance(self):
        """Test emissions estimation with invalid distance"""
        response = client.get("/emissions/estimate", params={"route_distance": -10.0})

        assert response.status_code == 422  # Validation error

    @patch("app.emissions.router.emission_storage")
    def test_estimate_emissions_with_username(self, mock_storage):
        """Test emissions estimation with username for history tracking"""
        mock_storage.store_emission_record.return_value = "record-456"

        response = client.get(
            "/emissions/estimate",
            params={
                "route_distance": 40.0,
                "username": "test_user",
                "session_id": "session-123",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert "record_id" in data
        mock_storage.store_emission_record.assert_called_once()


class TestEstimateForRoute:
    """Test cases for /emissions/estimate-for-route endpoint"""

    @patch("app.emissions.router.get_map_data")
    @patch("app.emissions.router.PathPlanner")
    @patch("app.emissions.router.emission_storage")
    def test_estimate_for_route_success(self, mock_storage, mock_planner, mock_get_map):
        """Test emissions estimation for specific route"""
        # Setup mocks
        mock_get_map.return_value = {
            "building_name": "TestBuilding",
            "_id": "map-123",
            "parking_map": [
                {
                    "building": "TestBuilding",
                    "level": 1,
                    "slots": [{"slot_id": "A1", "x": 5, "y": 5}],
                }
            ],
        }

        mock_planner_instance = MagicMock()
        mock_planner.return_value = mock_planner_instance
        mock_planner_instance.find_path.return_value = (
            [(1, 0, 3), (1, 2, 3), (1, 4, 4), (1, 5, 5)],
            25.5,
        )

        mock_storage.store_emission_record.return_value = "record-789"

        response = client.get(
            "/emissions/estimate-for-route",
            params={
                "start": "1,0,3",
                "end": "1,5,5",
                "building_name": "TestBuilding",
                "use_dynamic_baseline": True,
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["actual_distance"] == 25.5
        assert "emissions_saved" in data
        assert data["calculation_method"] == "dynamic"
        assert data["map_info"]["building_name"] == "TestBuilding"

    @patch("app.emissions.router.get_map_data")
    def test_estimate_for_route_map_not_found(self, mock_get_map):
        """Test route estimation when map not found"""
        mock_get_map.return_value = None

        response = client.get(
            "/emissions/estimate-for-route",
            params={"start": "1,0,0", "end": "1,5,5", "building_name": "NonExistent"},
        )

        assert response.status_code == 404
        assert "Map not found" in response.json()["detail"]

    @patch("app.emissions.router.get_map_data")
    def test_estimate_for_route_invalid_format(self, mock_get_map):
        """Test route estimation with invalid coordinate format"""
        mock_get_map.return_value = {
            "parking_map": [{"building": "Test", "level": 1, "slots": []}]
        }

        response = client.get(
            "/emissions/estimate-for-route",
            params={"start": "invalid", "end": "1,5,5", "building_name": "Test"},
        )

        assert response.status_code == 400

    @patch("app.emissions.router.get_map_data")
    @patch("app.emissions.router.PathPlanner")
    def test_estimate_for_route_no_path(self, mock_planner, mock_get_map):
        """Test when no path found between points"""
        mock_get_map.return_value = {
            "parking_map": [{"building": "Test", "level": 1, "slots": []}]
        }

        mock_planner_instance = MagicMock()
        mock_planner.return_value = mock_planner_instance
        mock_planner_instance.find_path.return_value = (None, 0)

        response = client.get(
            "/emissions/estimate-for-route",
            params={"start": "1,0,0", "end": "1,10,10", "building_name": "Test"},
        )

        assert response.status_code == 404
        assert "No path found" in response.json()["detail"]


class TestEstimateForParkingSearch:
    """Test cases for /emissions/estimate-for-parking-search endpoint"""

    @patch("app.emissions.router.get_map_data")
    @patch("app.emissions.router.PathPlanner")
    @patch("app.emissions.router.emission_storage")
    def test_parking_search_success(self, mock_storage, mock_planner, mock_get_map):
        """Test emissions for parking search from entrance"""
        mock_get_map.return_value = {
            "parking_map": [
                {
                    "entrances": [{"entrance_id": "E1", "x": 0, "y": 3}],
                    "slots": [{"slot_id": "A1", "x": 5, "y": 5, "status": "available"}],
                }
            ]
        }

        mock_planner_instance = MagicMock()
        mock_planner.return_value = mock_planner_instance
        mock_planner_instance.find_nearest_slot_to_entrance.return_value = {
            "entrance": {"entrance_id": "E1", "x": 0, "y": 3},
            "nearest_slot": {"slot_id": "A1", "x": 5, "y": 5},
            "path_distance": 15.0,
        }

        mock_storage.store_emission_record.return_value = "record-abc"

        response = client.get(
            "/emissions/estimate-for-parking-search",
            params={"entrance_id": "E1", "building_name": "TestBuilding"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["actual_distance"] == 15.0
        assert data["entrance"]["entrance_id"] == "E1"
        assert data["nearest_slot"]["slot_id"] == "A1"

    @patch("app.emissions.router.get_map_data")
    @patch("app.emissions.router.PathPlanner")
    def test_parking_search_entrance_not_found(self, mock_planner, mock_get_map):
        """Test when entrance not found"""
        mock_get_map.return_value = {"parking_map": [{"entrances": [], "slots": []}]}

        mock_planner_instance = MagicMock()
        mock_planner.return_value = mock_planner_instance
        mock_planner_instance.find_nearest_slot_to_entrance.return_value = {
            "error": "Entrance not found"
        }

        response = client.get(
            "/emissions/estimate-for-parking-search",
            params={"entrance_id": "E99", "building_name": "Test"},
        )

        assert response.status_code == 404


class TestFullParkingJourney:
    """Test cases for /emissions/estimate_full_parking_journey endpoint"""

    @patch("app.emissions.router.get_map_data")
    @patch("app.emissions.router.PathPlanner")
    @patch("app.emissions.router.emission_storage")
    def test_full_journey_success(self, mock_storage, mock_planner, mock_get_map):
        """Test full parking journey emissions calculation"""
        mock_get_map.return_value = {
            "building_name": "TestBuilding",
            "_id": "map-123",
            "parking_map": [
                {
                    "entrances": [{"entrance_id": "E1", "x": 0, "y": 3, "level": 1}],
                    "exits": [{"exit_id": "X1", "x": 10, "y": 8, "level": 1}],
                    "slots": [
                        {
                            "slot_id": "1A",
                            "x": 5,
                            "y": 5,
                            "level": 1,
                            "status": "available",
                        }
                    ],
                }
            ],
        }

        mock_planner_instance = MagicMock()
        mock_planner.return_value = mock_planner_instance
        # Path from entrance to slot
        mock_planner_instance.find_path.side_effect = [
            ([(1, 0, 3), (1, 3, 4), (1, 5, 5)], 15.0),  # Entrance to slot
            ([(1, 5, 5), (1, 7, 6), (1, 10, 8)], 12.0),  # Slot to exit
        ]

        mock_storage.store_emission_record.return_value = "record-xyz"

        response = client.get(
            "/emissions/estimate_full_parking_journey",
            params={
                "start": "E1",
                "slot_id": "1A",
                "exit": "X1",
                "building_name": "TestBuilding",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["total_distance"] == 27.0  # 15 + 12
        assert data["start_to_slot"]["distance"] == 15.0
        assert data["slot_to_exit"]["distance"] == 12.0
        assert "emissions_saved" in data
        assert "message" in data

    @patch("app.emissions.router.get_map_data")
    def test_full_journey_invalid_slot(self, mock_get_map):
        """Test full journey with invalid slot ID"""
        mock_get_map.return_value = {
            "parking_map": [
                {
                    "entrances": [{"entrance_id": "E1", "x": 0, "y": 3}],
                    "exits": [{"exit_id": "X1", "x": 10, "y": 8}],
                    "slots": [],
                }
            ]
        }

        response = client.get(
            "/emissions/estimate_full_parking_journey",
            params={
                "start": "E1",
                "slot_id": "NonExistent",
                "exit": "X1",
                "building_name": "Test",
            },
        )

        assert response.status_code == 400
        assert "Parking slot" in response.json()["detail"]

    @patch("app.emissions.router.get_map_data")
    def test_full_journey_invalid_coordinates(self, mock_get_map):
        """Test with invalid coordinate format"""
        mock_get_map.return_value = {
            "parking_map": [
                {
                    "entrances": [],
                    "exits": [{"exit_id": "X1", "x": 10, "y": 8}],
                    "slots": [{"slot_id": "1A", "x": 5, "y": 5}],
                }
            ]
        }

        response = client.get(
            "/emissions/estimate_full_parking_journey",
            params={
                "start": "invalid,format",
                "slot_id": "1A",
                "exit": "X1",
                "building_name": "Test",
            },
        )

        assert response.status_code == 400


class TestEmissionFactors:
    """Test cases for /emissions/factors endpoint"""

    def test_get_emission_factors(self):
        """Test getting emission calculation factors"""
        response = client.get("/emissions/factors")

        assert response.status_code == 200
        data = response.json()
        assert "co2_emissions_per_meter" in data
        assert "baseline_search_distance" in data
        assert "description" in data


class TestEmissionHistory:
    """Test cases for /emissions/history endpoint"""

    @patch("app.emissions.router.emission_storage")
    def test_get_emission_history(self, mock_storage):
        """Test getting emission history"""
        mock_storage.get_emission_history.return_value = [
            {
                "_id": ObjectId("507f1f77bcf86cd799439011"),
                "username": "test_user",
                "route_distance": 25.5,
                "emissions_saved": 10.2,
                "created_at": "2024-01-01T10:00:00Z",
            }
        ]

        response = client.get(
            "/emissions/history", params={"username": "test_user", "limit": 10}
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert len(data["records"]) == 1
        assert data["records"][0]["username"] == "test_user"

    @patch("app.emissions.router.emission_storage")
    def test_get_emission_history_empty(self, mock_storage):
        """Test getting empty emission history"""
        mock_storage.get_emission_history.return_value = []

        response = client.get("/emissions/history", params={"username": "new_user"})

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert len(data["records"]) == 0


class TestRecentEmissions:
    """Test cases for /emissions/recent endpoint"""

    @patch("app.emissions.router.emission_storage")
    def test_get_recent_emissions(self, mock_storage):
        """Test getting recent emissions"""
        mock_storage.get_recent_emissions.return_value = [
            {
                "_id": ObjectId("507f1f77bcf86cd799439012"),
                "route_distance": 30.0,
                "emissions_saved": 12.5,
                "created_at": "2024-01-02T15:00:00Z",
            },
            {
                "_id": ObjectId("507f1f77bcf86cd799439013"),
                "route_distance": 20.0,
                "emissions_saved": 8.0,
                "created_at": "2024-01-02T14:00:00Z",
            },
        ]

        response = client.get("/emissions/recent", params={"limit": 5})

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["count"] == 2
        assert len(data["records"]) == 2


class TestClearEmissions:
    """Test cases for /emissions/clear endpoint"""

    @patch("app.emissions.router.emission_storage")
    def test_clear_emissions_with_confirmation(self, mock_storage):
        """Test clearing emissions with confirmation"""
        mock_storage.delete_emission_records.return_value = 5

        response = client.delete(
            "/emissions/clear",
            params={"username": "test_user", "confirm": True},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["deleted_count"] == 5
        assert "test_user" in data["message"]

    def test_clear_emissions_without_confirmation(self):
        """Test clearing emissions without confirmation"""
        response = client.delete(
            "/emissions/clear",
            params={"username": "test_user", "confirm": False},
        )

        assert response.status_code == 400
        assert "confirm=true" in response.json()["detail"]

    def test_clear_emissions_no_filter(self):
        """Test clearing emissions without username or session"""
        response = client.delete("/emissions/clear", params={"confirm": True})

        assert response.status_code == 400
        assert "username or session_id" in response.json()["detail"]


class TestSessionJourneyEmissions:
    """Test cases for /emissions/estimate-session-journey endpoint"""

    @patch("app.database.user_collection")
    @patch("app.emissions.router.session_collection")
    @patch("app.emissions.router.get_map_data")
    @patch("app.emissions.router.PathPlanner")
    @patch("app.emissions.router.emission_storage")
    def test_session_journey_success(
        self, mock_storage, mock_planner, mock_get_map, mock_session, mock_user
    ):
        """Test session journey emissions calculation"""
        # Mock session data with valid ObjectId
        mock_session.find_one.return_value = {
            "session_id": "session-123",
            "slot_id": "1A",
            "entrance_id": "E1",
            "exit_id": "X1",
            "user_id": ObjectId("507f1f77bcf86cd799439011"),
        }

        # Mock user data
        mock_user.find_one.return_value = {
            "_id": ObjectId("507f1f77bcf86cd799439011"),
            "username": "test_user",
        }

        # Mock map data
        mock_get_map.return_value = {
            "building_name": "TestBuilding",
            "_id": "map-123",
            "parking_map": [
                {
                    "entrances": [{"entrance_id": "E1", "x": 0, "y": 3, "level": 1}],
                    "exits": [{"exit_id": "X1", "x": 10, "y": 8, "level": 1}],
                    "slots": [{"slot_id": "1A", "x": 5, "y": 5, "level": 1}],
                }
            ],
        }

        # Mock path planning
        mock_planner_instance = MagicMock()
        mock_planner.return_value = mock_planner_instance
        mock_planner_instance.find_path.side_effect = [
            ([(1, 0, 3), (1, 5, 5)], 10.0),  # Entrance to slot
            ([(1, 5, 5), (1, 10, 8)], 8.0),  # Slot to exit
        ]

        mock_storage.store_emission_record.return_value = "record-session"

        response = client.get(
            "/emissions/estimate-session-journey",
            params={"session_id": "session-123", "building_name": "TestBuilding"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["total_distance"] == 18.0
        assert data["session_info"]["session_id"] == "session-123"

    @patch("app.emissions.router.session_collection")
    def test_session_journey_not_found(self, mock_session):
        """Test session journey when session not found"""
        mock_session.find_one.return_value = None

        response = client.get(
            "/emissions/estimate-session-journey",
            params={"session_id": "non-existent"},
        )

        assert response.status_code == 404
        assert "Session not found" in response.json()["detail"]

    @patch("app.emissions.router.session_collection")
    def test_session_journey_missing_data(self, mock_session):
        """Test session journey with missing entrance/exit data"""
        mock_session.find_one.return_value = {
            "session_id": "session-123",
            "slot_id": "1A",
            # Missing entrance_id and exit_id
        }

        response = client.get(
            "/emissions/estimate-session-journey",
            params={"session_id": "session-123"},
        )

        assert response.status_code == 400


class TestErrorHandling:
    """Test error handling scenarios"""

    @patch("app.emissions.router.calculate_emissions_saved")
    def test_calculation_error(self, mock_calculate):
        """Test handling of calculation errors"""
        mock_calculate.side_effect = Exception("Calculation failed")

        response = client.get("/emissions/estimate", params={"route_distance": 50.0})

        assert response.status_code == 500
        assert "Failed to calculate emissions" in response.json()["detail"]

    @patch("app.emissions.router.emission_storage")
    def test_storage_failure_non_blocking(self, mock_storage):
        """Test that storage failures don't block the response"""
        mock_storage.store_emission_record.side_effect = Exception("Storage failed")

        response = client.get("/emissions/estimate", params={"route_distance": 30.0})

        # Should still return success even if storage fails
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "record_id" not in data  # No record ID since storage failed
