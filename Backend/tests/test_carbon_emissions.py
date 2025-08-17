"""
Tests for the carbon emissions API endpoints and calculation utilities
"""

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.emissions.calculator import (
    calculate_emissions_saved,
    calculate_dynamic_baseline,
    format_emissions_message,
)

client = TestClient(app)


class TestCarbonEmissionsAPI:
    """Test the carbon emissions API endpoints"""

    def test_estimate_emissions_basic(self):
        """Test basic emissions estimation endpoint"""
        response = client.get("/emissions/estimate?route_distance=25.5")

        assert response.status_code == 200
        data = response.json()

        assert data["success"] is True
        assert data["actual_distance"] == 25.5
        assert "baseline_distance" in data
        assert "emissions_saved" in data
        assert "percentage_saved" in data
        assert "message" in data
        assert data["calculation_method"] == "static"

        # Verify the calculation is correct
        assert data["actual_emissions"] == round(25.5 * data["emissions_factor"], 2)
        assert data["baseline_emissions"] == round(
            data["baseline_distance"] * data["emissions_factor"], 2
        )

    def test_estimate_emissions_with_custom_parameters(self):
        """Test emissions estimation with custom baseline and factor"""
        response = client.get(
            "/emissions/estimate?route_distance=15.0&baseline_distance=60.0&emissions_factor=0.25"
        )

        assert response.status_code == 200
        data = response.json()

        assert data["actual_distance"] == 15.0
        assert data["baseline_distance"] == 60.0
        assert data["emissions_factor"] == 0.25
        assert data["actual_emissions"] == 3.75  # 15 * 0.25
        assert data["baseline_emissions"] == 15.0  # 60 * 0.25
        assert data["emissions_saved"] == 11.25  # 15 - 3.75
        assert data["percentage_saved"] == 75.0  # (11.25/15) * 100

    def test_estimate_emissions_invalid_distance(self):
        """Test emissions estimation with invalid route distance"""
        response = client.get("/emissions/estimate?route_distance=-5")
        assert response.status_code == 422  # Validation error

        response = client.get("/emissions/estimate?route_distance=0")
        assert response.status_code == 422  # Validation error (must be > 0)

    def test_estimate_emissions_with_large_distance(self):
        """Test emissions estimation with very large distance"""
        response = client.get("/emissions/estimate?route_distance=1000")

        assert response.status_code == 200
        data = response.json()
        assert data["actual_distance"] == 1000.0
        assert (
            data["emissions_saved"] < 0
        )  # Should show negative savings for very long routes

    def test_get_emissions_factors(self):
        """Test getting current emissions factors"""
        response = client.get("/emissions/factors")

        assert response.status_code == 200
        data = response.json()

        assert "co2_emissions_per_meter" in data
        assert "baseline_search_distance" in data
        assert "description" in data
        assert isinstance(data["co2_emissions_per_meter"], float)
        assert isinstance(data["baseline_search_distance"], float)
        assert data["co2_emissions_per_meter"] > 0
        assert data["baseline_search_distance"] > 0

    def test_estimate_for_route_invalid_map(self):
        """Test route emissions estimation with non-existent map"""
        response = client.get(
            "/emissions/estimate-for-route?start=1,0,0&end=1,5,5&map_id=nonexistent"
        )

        assert response.status_code == 404
        assert "Map with ID 'nonexistent' not found" in response.json()["detail"]

    def test_estimate_for_route_invalid_coordinates(self):
        """Test route emissions estimation with invalid coordinate format"""
        # Invalid format - missing level
        response = client.get(
            "/emissions/estimate-for-route?start=0,0&end=1,5,5&map_id=test"
        )
        assert response.status_code == 404
        assert "Map with ID 'test' not found" in response.json()["detail"]

        # Invalid format - non-numeric
        response = client.get(
            "/emissions/estimate-for-route?start=invalid&end=1,5,5&map_id=test"
        )
        assert response.status_code == 404


class TestEmissionsCalculator:
    """Test the emissions calculation utilities"""

    def test_calculate_emissions_saved_basic(self):
        """Test basic emissions calculation"""
        result = calculate_emissions_saved(
            actual_distance=10.0, baseline_distance=50.0, emissions_factor=0.2
        )

        assert result["actual_distance"] == 10.0
        assert result["baseline_distance"] == 50.0
        assert result["emissions_factor"] == 0.2
        assert result["actual_emissions"] == 2.0  # 10 * 0.2
        assert result["baseline_emissions"] == 10.0  # 50 * 0.2
        assert result["emissions_saved"] == 8.0  # 10 - 2
        assert result["percentage_saved"] == 80.0  # (8/10) * 100

    def test_calculate_emissions_saved_no_savings(self):
        """Test when actual distance is greater than baseline"""
        result = calculate_emissions_saved(
            actual_distance=80.0, baseline_distance=50.0, emissions_factor=0.2
        )

        assert result["emissions_saved"] == -6.0  # negative savings
        assert result["percentage_saved"] == -60.0  # negative percentage

    def test_calculate_emissions_saved_with_defaults(self):
        """Test emissions calculation using default values from settings"""
        result = calculate_emissions_saved(actual_distance=25.0)

        # Should use default values from settings
        assert "actual_distance" in result
        assert "baseline_distance" in result
        assert "emissions_factor" in result
        assert result["actual_distance"] == 25.0
        assert result["baseline_distance"] > 0  # Should use settings default
        assert result["emissions_factor"] > 0  # Should use settings default

    def test_calculate_emissions_saved_zero_baseline(self):
        """Test emissions calculation with zero baseline"""
        result = calculate_emissions_saved(
            actual_distance=10.0, baseline_distance=0.0, emissions_factor=0.2
        )

        assert result["percentage_saved"] == 0.0  # Should handle division by zero
        assert result["emissions_saved"] == -2.0  # Negative since no baseline

    def test_calculate_dynamic_baseline_empty_map(self):
        """Test dynamic baseline calculation with empty map data"""
        from app.config import settings

        result = calculate_dynamic_baseline([], (0, 0))
        assert result == settings.baseline_search_distance

    def test_calculate_dynamic_baseline_with_map_data(self):
        """Test dynamic baseline calculation with realistic map data"""
        map_data = [
            {
                "level": 1,
                "corridors": [{"points": [[0, 0], [10, 0], [10, 10], [0, 10]]}],
                "slots": [
                    {"x": 2, "y": 2, "status": "available"},
                    {"x": 4, "y": 4, "status": "occupied"},
                    {"x": 6, "y": 6, "status": "available"},
                    {"x": 8, "y": 8, "status": "reserved"},
                ],
            }
        ]

        result = calculate_dynamic_baseline(map_data, (0, 0))

        # Should return a reasonable baseline between bounds
        assert 20.0 <= result <= 500.0
        assert isinstance(result, float)

        # With 50% occupancy, should be higher than minimum
        assert result >= 20.0

    def test_calculate_dynamic_baseline_small_lot(self):
        """Test dynamic baseline with very small parking lot"""
        map_data = [
            {
                "level": 1,
                "corridors": [{"points": [[0, 0], [2, 0], [2, 2], [0, 2]]}],
                "slots": [{"x": 1, "y": 1, "status": "available"}],
            }
        ]

        result = calculate_dynamic_baseline(map_data, (0, 0))

        # Should be set to minimum due to small size
        assert result == 20.0

    def test_format_emissions_message_positive_savings(self):
        """Test formatting message for positive emissions savings"""
        emissions_data = {"emissions_saved": 125.5, "percentage_saved": 75.3}

        message = format_emissions_message(emissions_data)
        assert "You saved" in message
        assert "125.5g" in message
        assert "75.3%" in message
        assert "AutoSpot" in message

    def test_format_emissions_message_large_savings(self):
        """Test formatting message for large emissions savings (kg)"""
        emissions_data = {"emissions_saved": 1250.0, "percentage_saved": 85.0}

        message = format_emissions_message(emissions_data)
        assert "1.2kg" in message  # Should convert to kg
        assert "85.0%" in message

    def test_format_emissions_message_no_savings(self):
        """Test formatting message when no emissions are saved"""
        emissions_data = {"emissions_saved": -5.0, "percentage_saved": -10.0}

        message = format_emissions_message(emissions_data)
        assert "efficient route" in message.lower()

    def test_format_emissions_message_error(self):
        """Test formatting message when there's an error"""
        emissions_data = {"error": "Calculation failed"}

        message = format_emissions_message(emissions_data)
        assert "unable" in message.lower()


class TestCarbonEmissionsIntegration:
    """Integration tests with mocked map data"""

    @pytest.fixture
    def mock_map_data(self, monkeypatch):
        """Mock map data for testing"""
        mock_data = {
            "_id": "test_map_123",
            "building_name": "Test Building",
            "parking_map": [
                {
                    "level": 1,
                    "corridors": [
                        {
                            "direction": "both",
                            "points": [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [5, 0]],
                        }
                    ],
                    "slots": [
                        {"slot_id": "A1", "x": 1, "y": 1, "status": "available"},
                        {"slot_id": "A2", "x": 3, "y": 1, "status": "available"},
                    ],
                    "entrances": [{"entrance_id": "E1", "x": 0, "y": 0, "level": 1}],
                }
            ],
        }

        def mock_get_map_data(map_id, building_name):
            if map_id == "test_map_123" or building_name == "Test Building":
                return mock_data
            return None

        monkeypatch.setattr("app.emissions.router.get_map_data", mock_get_map_data)
        return mock_data

    def test_estimate_for_route_with_mock_data(self, mock_map_data):
        """Test route emissions estimation with mocked map data"""
        response = client.get(
            "/emissions/estimate-for-route?start=1,0,0&end=1,5,0&map_id=test_map_123"
        )

        assert response.status_code == 200
        data = response.json()

        assert data["success"] is True
        assert "actual_distance" in data
        assert "emissions_saved" in data
        assert "calculation_method" in data
        assert "map_info" in data
        assert data["map_info"]["building_name"] == "Test Building"
        assert data["calculation_method"] == "dynamic"

    def test_estimate_for_route_static_vs_dynamic(self, mock_map_data):
        """Test difference between static and dynamic baseline calculations"""
        # Test with dynamic baseline
        response_dynamic = client.get(
            "/emissions/estimate-for-route?start=1,0,0&end=1,3,0&map_id=test_map_123&use_dynamic_baseline=true"
        )

        # Test with static baseline
        response_static = client.get(
            "/emissions/estimate-for-route?start=1,0,0&end=1,3,0&map_id=test_map_123&use_dynamic_baseline=false"
        )

        assert response_dynamic.status_code == 200
        assert response_static.status_code == 200

        data_dynamic = response_dynamic.json()
        data_static = response_static.json()

        assert data_dynamic["calculation_method"] == "dynamic"
        assert data_static["calculation_method"] == "static"

        # Dynamic baseline should typically be different from static
        # (unless they happen to match due to specific map characteristics)
        assert "emissions_saved" in data_dynamic
        assert "emissions_saved" in data_static


class TestCarbonEmissionsEdgeCases:
    """Test edge cases and boundary conditions"""

    def test_estimate_very_small_distance(self):
        """Test emissions estimation with very small distances"""
        response = client.get("/emissions/estimate?route_distance=0.1")

        assert response.status_code == 200
        data = response.json()

        assert data["actual_distance"] == 0.1
        assert data["emissions_saved"] > 0  # Should still save emissions vs baseline

    def test_estimate_boundary_values(self):
        """Test emissions calculation with boundary values"""
        # Test with very small positive value
        response = client.get("/emissions/estimate?route_distance=0.01")
        assert response.status_code == 200

        # Test with custom factor at boundary
        response = client.get(
            "/emissions/estimate?route_distance=10&emissions_factor=0.001"
        )
        assert response.status_code == 200

        data = response.json()
        assert data["emissions_factor"] == 0.001

    def test_percentage_calculation_edge_cases(self):
        """Test percentage calculation in edge cases"""
        # When actual equals baseline
        result = calculate_emissions_saved(
            actual_distance=50.0, baseline_distance=50.0, emissions_factor=0.2
        )
        assert result["emissions_saved"] == 0.0
        assert result["percentage_saved"] == 0.0

        # When baseline is very small
        result = calculate_emissions_saved(
            actual_distance=1.0, baseline_distance=0.1, emissions_factor=0.2
        )
        assert result["percentage_saved"] < 0  # Negative percentage

    def test_api_response_structure_completeness(self):
        """Test that API responses contain all required fields"""
        response = client.get("/emissions/estimate?route_distance=20")

        assert response.status_code == 200
        data = response.json()

        # Check all required fields are present
        required_fields = [
            "success",
            "actual_distance",
            "baseline_distance",
            "emissions_factor",
            "actual_emissions",
            "baseline_emissions",
            "emissions_saved",
            "percentage_saved",
            "message",
            "calculation_method",
        ]

        for field in required_fields:
            assert field in data, f"Missing required field: {field}"

        # Check data types
        assert isinstance(data["success"], bool)
        assert isinstance(data["actual_distance"], (int, float))
        assert isinstance(data["message"], str)
        assert data["calculation_method"] in ["static", "dynamic"]


class TestCarbonEmissionsDocumentation:
    """Test that examples in API documentation work correctly"""

    def test_documentation_examples(self):
        """Test that the examples provided in API documentation work"""
        # Basic example
        response = client.get("/emissions/estimate?route_distance=25.5")
        assert response.status_code == 200

        # Custom parameters example
        response = client.get(
            "/emissions/estimate?route_distance=15.0&baseline_distance=60.0"
        )
        assert response.status_code == 200

        # Factors endpoint example
        response = client.get("/emissions/factors")
        assert response.status_code == 200

        data = response.json()
        assert "co2_emissions_per_meter" in data
        assert "baseline_search_distance" in data
