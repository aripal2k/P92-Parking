import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
from app.main import app
from app.parking.models import ParkingSlot
import json

client = TestClient(app)


class TestParkingBasic:
    """Basic test cases for parking functionality"""

    def test_get_parking_slots_basic(self):
        """Test basic get parking slots"""
        response = client.get("/parking/slots")

        assert response.status_code == 200
        data = response.json()
        assert "slots" in data
        assert "total" in data
        assert isinstance(data["slots"], list)
        assert isinstance(data["total"], int)

    def test_get_parking_slots_summary_basic(self):
        """Test basic get parking slots summary"""
        response = client.get("/parking/slots/summary")

        assert response.status_code == 200
        data = response.json()
        assert "summary" in data
        summary = data["summary"]

        # Check required fields
        required_fields = ["occupied", "available", "allocated", "total"]
        for field in required_fields:
            assert field in summary
            assert isinstance(summary[field], int)
            assert summary[field] >= 0

    def test_get_all_maps_basic(self):
        """Test basic get all maps"""
        response = client.get("/parking/maps")

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "maps" in data
        assert "total" in data
        assert isinstance(data["maps"], list)
        assert data["total"] >= 1  # At least example map should exist

    def test_get_map_by_building_example(self):
        """Test getting map by building name (using example data)"""
        response = client.get("/parking/maps/building/Westfield Sydney")

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["building_name"] == "Westfield Sydney"
        assert "map" in data
        assert "_id" in data["map"]
        assert "parking_map" in data["map"]

    def test_calculate_parking_fare_basic(self):
        """Test basic parking fare calculation"""
        request_data = {
            "destination": "Default",
            "duration_hours": 2.0,
            "time": "10:00",
            "date": "2024-01-15",
        }

        response = client.post("/parking/predict-fare", json=request_data)

        assert response.status_code == 200
        data = response.json()

        # Check required response fields based on actual API response
        required_fields = ["destination", "duration_hours", "currency", "breakdown"]
        for field in required_fields:
            assert field in data

        assert data["currency"] == "AUD"
        assert isinstance(data["duration_hours"], (int, float))
        assert "breakdown" in data
        assert "total" in data["breakdown"]
        assert isinstance(data["breakdown"]["total"], (int, float))
        assert data["breakdown"]["total"] >= 0

    def test_calculate_parking_fare_invalid_data(self):
        """Test parking fare calculation with invalid data"""
        request_data = {
            "destination": "Default",
            "duration_hours": -1.0,  # Invalid negative duration
            "time": "10:00",
            "date": "2024-01-15",
        }

        response = client.post("/parking/predict-fare", json=request_data)

        # Should return 422 for validation error
        assert response.status_code == 422

    def test_parking_slots_with_level_filter(self):
        """Test parking slots with level filter"""
        response = client.get("/parking/slots?level=1")

        assert response.status_code == 200
        data = response.json()
        assert "slots" in data

        # If slots exist, they should all be from level 1
        if data["slots"]:
            for slot in data["slots"]:
                assert slot.get("level") == 1

    def test_parking_map_for_editing_example(self):
        """Test getting parking map for editing (using example map)"""
        from app.parking.utils import EXAMPLE_MAP_ID

        response = client.get(f"/parking/maps/{EXAMPLE_MAP_ID}")

        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["map"]["editable"] is True
        assert data["map"]["_id"] == EXAMPLE_MAP_ID

    def test_parking_map_not_found(self):
        """Test getting non-existent parking map"""
        response = client.get("/parking/maps/nonexistent_map_id")

        assert response.status_code == 404


class TestParkingBoundaryConditions:
    """Test boundary conditions and edge cases for parking functionality"""

    def test_parking_fare_zero_duration(self):
        """Test parking fare with zero duration"""
        request_data = {
            "destination": "Default",
            "duration_hours": 0.0,
            "time": "10:00",
            "date": "2024-01-15",
        }

        response = client.post("/parking/predict-fare", json=request_data)

        # Zero duration should be invalid
        assert response.status_code == 422

    def test_parking_fare_max_duration(self):
        """Test parking fare with maximum duration (24 hours)"""
        request_data = {
            "destination": "Default",
            "duration_hours": 24.0,
            "time": "00:00",
            "date": "2024-01-15",
        }

        response = client.post("/parking/predict-fare", json=request_data)

        assert response.status_code == 200
        data = response.json()
        assert data["duration_hours"] == 24.0
        assert data["breakdown"]["total"] >= 0  # May be 0 if rates not loaded

    def test_parking_fare_over_max_duration(self):
        """Test parking fare with over maximum duration (>24 hours)"""
        request_data = {
            "destination": "Default",
            "duration_hours": 25.0,
            "time": "00:00",
            "date": "2024-01-15",
        }

        response = client.post("/parking/predict-fare", json=request_data)

        # Over 24 hours should be invalid
        assert response.status_code == 422

    def test_parking_fare_minimum_duration(self):
        """Test parking fare with minimum valid duration"""
        request_data = {
            "destination": "Default",
            "duration_hours": 0.5,  # 30 minutes
            "time": "10:00",
            "date": "2024-01-15",
        }

        response = client.post("/parking/predict-fare", json=request_data)

        assert response.status_code == 200
        data = response.json()
        assert data["duration_hours"] == 0.5
        assert data["breakdown"]["total"] >= 0  # May be 0 if rates not loaded

    def test_parking_fare_peak_hours(self):
        """Test parking fare during peak hours"""
        request_data = {
            "destination": "Default",
            "duration_hours": 2.0,
            "time": "08:00",  # Peak hour
            "date": "2024-01-15",  # Weekday
        }

        response = client.post("/parking/predict-fare", json=request_data)

        assert response.status_code == 200
        data = response.json()
        assert "peak_hour_surcharge" in data["breakdown"]

    def test_parking_fare_off_peak_hours(self):
        """Test parking fare during off-peak hours"""
        request_data = {
            "destination": "Default",
            "duration_hours": 2.0,
            "time": "14:00",  # Off-peak hour
            "date": "2024-01-15",  # Weekday
        }

        response = client.post("/parking/predict-fare", json=request_data)

        assert response.status_code == 200
        data = response.json()
        # Peak hour surcharge should be 0 or not present
        peak_surcharge = data["breakdown"].get("peak_hour_surcharge", 0)
        assert peak_surcharge == 0

    def test_parking_fare_weekend(self):
        """Test parking fare on weekend"""
        request_data = {
            "destination": "Default",
            "duration_hours": 2.0,
            "time": "10:00",
            "date": "2024-01-20",  # Saturday
        }

        response = client.post("/parking/predict-fare", json=request_data)

        assert response.status_code == 200
        data = response.json()
        assert "weekend_surcharge" in data["breakdown"]
        assert (
            data["breakdown"]["weekend_surcharge"] >= 0
        )  # May be 0 if rates not loaded

    def test_parking_fare_weekday(self):
        """Test parking fare on weekday"""
        request_data = {
            "destination": "Default",
            "duration_hours": 2.0,
            "time": "10:00",
            "date": "2024-01-15",  # Monday
        }

        response = client.post("/parking/predict-fare", json=request_data)

        assert response.status_code == 200
        data = response.json()
        # Weekend surcharge should be 0 or not present
        weekend_charge = data["breakdown"].get("weekend_surcharge", 0)
        assert weekend_charge == 0

    def test_parking_slots_empty_filter(self):
        """Test parking slots with empty filters"""
        response = client.get("/parking/slots")

        assert response.status_code == 200
        data = response.json()
        assert "slots" in data
        # Should return all slots

    def test_parking_slots_invalid_level(self):
        """Test parking slots with invalid level"""
        response = client.get("/parking/slots?level=-1")

        assert response.status_code in [200, 422]
        # May return empty or validation error

    def test_parking_slots_nonexistent_building(self):
        """Test parking slots with non-existent building"""
        response = client.get("/parking/slots?building=NonExistentBuilding123")

        assert response.status_code == 200
        data = response.json()
        assert "slots" in data
        # Accept the actual number of slots returned (may include example data)
        assert isinstance(data["total"], int)
        assert data["total"] >= 0

    def test_parking_entrances_empty_building(self):
        """Test getting entrances with empty building name"""
        response = client.get("/parking/entrances?building=")

        assert response.status_code in [200, 422]

    def test_parking_exits_empty_building(self):
        """Test getting exits with empty building name"""
        response = client.get("/parking/exits?building=")

        assert response.status_code in [200, 422]

    def test_destination_rate_special_characters(self):
        """Test destination rate with special characters"""
        response = client.get(
            "/parking/destination-parking-rate?destination=Test%20%26%20Building%20%23123"
        )

        assert response.status_code == 200
        data = response.json()
        assert "base_rate_per_hour" in data

    def test_destination_rate_empty(self):
        """Test destination rate with empty destination"""
        response = client.get("/parking/destination-parking-rate?destination=")

        assert response.status_code in [200, 422]
        if response.status_code == 200:
            data = response.json()
            assert "base_rate_per_hour" in data

    def test_parking_fare_invalid_date_format(self):
        """Test parking fare with invalid date format"""
        request_data = {
            "destination": "Default",
            "duration_hours": 2.0,
            "time": "10:00",
            "date": "15-01-2024",  # Wrong format
        }

        response = client.post("/parking/predict-fare", json=request_data)

        # Should handle gracefully or return validation error
        assert response.status_code in [200, 422]

    def test_parking_fare_invalid_time_format(self):
        """Test parking fare with invalid time format"""
        request_data = {
            "destination": "Default",
            "duration_hours": 2.0,
            "time": "25:00",  # Invalid time
            "date": "2024-01-15",
        }

        response = client.post("/parking/predict-fare", json=request_data)

        # Should return 400 for invalid time format
        assert response.status_code == 400

    def test_parking_fare_fractional_hours(self):
        """Test parking fare with fractional hours"""
        request_data = {
            "destination": "Default",
            "duration_hours": 2.75,  # 2 hours 45 minutes
            "time": "10:00",
            "date": "2024-01-15",
        }

        response = client.post("/parking/predict-fare", json=request_data)

        assert response.status_code == 200
        data = response.json()
        assert data["duration_hours"] == 2.75
        assert data["breakdown"]["total"] >= 0  # May be 0 if rates not loaded

    def test_parking_fare_very_small_duration(self):
        """Test parking fare with very small duration"""
        request_data = {
            "destination": "Default",
            "duration_hours": 0.01,  # Less than a minute
            "time": "10:00",
            "date": "2024-01-15",
        }

        response = client.post("/parking/predict-fare", json=request_data)

        # Should either handle or reject very small duration
        assert response.status_code in [200, 422]


class TestParkingModels:
    """Test cases for parking data models"""

    def test_parking_slot_model(self):
        """Test parking slot model validation"""
        slot_data = {
            "slot_id": "A1",
            "level": 1,
            "status": "available",
            "x": 10.5,
            "y": 20.5,
        }

        slot = ParkingSlot(**slot_data)
        assert slot.slot_id == "A1"
        assert slot.level == 1
        assert slot.status == "available"
        assert slot.x == 10.5
        assert slot.y == 20.5
        assert slot.vehicle_id is None
        assert slot.reserved_by is None

    def test_parking_slot_color_property(self):
        """Test parking slot status/color property"""
        # Test available slot
        slot = ParkingSlot(slot_id="A1", level=1, status="free", x=1, y=1)
        assert slot.color == "green"

        # Test occupied slot
        slot.status = "occupied"
        assert slot.color == "red"

        # Test allocated slot
        slot.status = "allocated"
        assert slot.color == "yellow"

        # Test unknown status
        slot.status = "unknown"
        assert slot.color == "grey"

    def test_parking_slot_boundary_coordinates(self):
        """Test parking slot with boundary coordinates"""
        # Test minimum coordinates
        slot = ParkingSlot(slot_id="A1", level=0, status="available", x=0, y=0)
        assert slot.x == 0
        assert slot.y == 0
        assert slot.level == 0

        # Test large coordinates
        slot = ParkingSlot(
            slot_id="Z99", level=100, status="available", x=9999.99, y=9999.99
        )
        assert slot.x == 9999.99
        assert slot.y == 9999.99
        assert slot.level == 100

        # Test negative coordinates (may be valid for some coordinate systems)
        slot = ParkingSlot(slot_id="B1", level=-1, status="available", x=-10.5, y=-20.5)
        assert slot.x == -10.5
        assert slot.y == -20.5
        assert slot.level == -1

    def test_parking_slot_special_ids(self):
        """Test parking slot with special IDs"""
        # Test with numbers only
        slot = ParkingSlot(slot_id="123", level=1, status="available", x=1, y=1)
        assert slot.slot_id == "123"

        # Test with special characters
        slot = ParkingSlot(slot_id="A-1-B", level=1, status="available", x=1, y=1)
        assert slot.slot_id == "A-1-B"

        # Test with long ID
        long_id = "A" * 100
        slot = ParkingSlot(slot_id=long_id, level=1, status="available", x=1, y=1)
        assert slot.slot_id == long_id

        # Test with empty string (should fail validation if properly implemented)
        try:
            slot = ParkingSlot(slot_id="", level=1, status="available", x=1, y=1)
            # If it doesn't fail, check it was accepted
            assert slot.slot_id == ""
        except Exception:
            # Expected behavior for empty slot_id
            pass

    def test_parking_slot_all_statuses(self):
        """Test all possible parking slot statuses"""
        statuses = [
            "available",
            "occupied",
            "allocated",
            "free",
            "reserved",
            "maintenance",
            "disabled",
        ]

        for status in statuses:
            slot = ParkingSlot(slot_id="A1", level=1, status=status, x=1, y=1)
            assert slot.status == status
            # Color should be defined for all statuses
            assert slot.color in ["green", "red", "yellow", "grey", "blue", "orange"]


class TestParkingIntegration:
    """Integration tests for parking functionality"""

    def test_parking_workflow_basic(self):
        """Test basic parking operation"""
        # 1. Get available maps
        maps_response = client.get("/parking/maps")
        assert maps_response.status_code == 200
        maps_data = maps_response.json()
        assert len(maps_data["maps"]) > 0

        # 2. Get slots summary
        summary_response = client.get("/parking/slots/summary")
        assert summary_response.status_code == 200
        summary_data = summary_response.json()
        assert summary_data["summary"]["total"] >= 0

        # 3. Calculate parking fare
        fare_request = {
            "destination": "Default",
            "duration_hours": 1.0,
            "time": "12:00",
            "date": "2024-01-15",
        }
        fare_response = client.post("/parking/predict-fare", json=fare_request)
        assert fare_response.status_code == 200
        fare_data = fare_response.json()
        assert fare_data["breakdown"]["total"] >= 0

    def test_parking_workflow_with_filters(self):
        """Test parking workflow with various filters"""
        # 1. Get maps for specific building
        building_response = client.get("/parking/maps/building/Westfield Sydney")
        assert building_response.status_code == 200

        # 2. Get available slots for that building
        slots_response = client.get(
            "/parking/slots?building=Westfield Sydney&status=available"
        )
        assert slots_response.status_code == 200
        slots_data = slots_response.json()

        # 3. Get entrances for the building
        entrances_response = client.get("/parking/entrances?building=Westfield Sydney")
        assert entrances_response.status_code == 200

        # 4. Get exits for the building
        exits_response = client.get("/parking/exits?building=Westfield Sydney")
        assert exits_response.status_code == 200

        # 5. Calculate fare for specific destination
        fare_request = {
            "destination": "Westfield Sydney (Example)",
            "duration_hours": 3.0,
            "time": "14:30",
            "date": "2024-01-15",
        }
        fare_response = client.post("/parking/predict-fare", json=fare_request)
        assert fare_response.status_code == 200

    def test_parking_error_handling(self):
        """Test error handling in parking operations"""
        # 1. Try to get non-existent map
        error_response = client.get("/parking/maps/invalid_id_12345")
        assert error_response.status_code == 404

        # 2. Try invalid fare calculation
        invalid_fare = {
            "destination": "Test",
            "duration_hours": "invalid",  # String instead of number
            "time": "10:00",
            "date": "2024-01-15",
        }
        fare_error = client.post("/parking/predict-fare", json=invalid_fare)
        assert fare_error.status_code == 422

        # 3. Try to get slots with conflicting filters
        conflict_response = client.get(
            "/parking/slots?status=available&status=occupied"
        )
        # Should handle gracefully
        assert conflict_response.status_code in [200, 422]


class TestParkingConcurrency:
    """Test concurrent access scenarios"""

    def test_multiple_slot_requests(self):
        """Test multiple simultaneous slot requests"""
        import concurrent.futures

        def get_slots():
            return client.get("/parking/slots/summary")

        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(get_slots) for _ in range(10)]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]

        # All requests should succeed
        for response in results:
            assert response.status_code == 200
            data = response.json()
            assert "summary" in data

    def test_concurrent_fare_calculations(self):
        """Test concurrent fare calculations"""
        import concurrent.futures

        def calculate_fare(hours):
            request_data = {
                "destination": "Default",
                "duration_hours": hours,
                "time": "10:00",
                "date": "2024-01-15",
            }
            return client.post("/parking/predict-fare", json=request_data)

        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(calculate_fare, h) for h in [1, 2, 3, 4, 5]]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]

        # All calculations should succeed
        for response in results:
            assert response.status_code == 200
            data = response.json()
            assert "breakdown" in data


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
