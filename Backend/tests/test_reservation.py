"""
Tests for Reservation functionality

Starting with basic model validation tests.
"""

import pytest
from datetime import datetime, timezone
from pydantic import ValidationError

from app.reservation.models import Reservation


class TestReservationModel:
    """Test the basic Reservation Pydantic model"""

    def test_reservation_model_valid_data(self):
        """Test creating a Reservation with valid data"""
        reservation_data = {
            "reservation_id": "RES-001",
            "slot_id": "SLOT-A1",
            "user_id": "USER-123",
            "start_time": datetime(2025, 7, 31, 10, 0, 0, tzinfo=timezone.utc),
            "end_time": datetime(2025, 7, 31, 12, 0, 0, tzinfo=timezone.utc),
            "status": "active",
        }

        reservation = Reservation(**reservation_data)

        # Verify all fields are set correctly
        assert reservation.reservation_id == "RES-001"
        assert reservation.slot_id == "SLOT-A1"
        assert reservation.user_id == "USER-123"
        assert reservation.start_time == reservation_data["start_time"]
        assert reservation.end_time == reservation_data["end_time"]
        assert reservation.status == "active"

    def test_reservation_model_different_statuses(self):
        """Test Reservation model with different valid status values"""
        base_data = {
            "reservation_id": "RES-002",
            "slot_id": "SLOT-B2",
            "user_id": "USER-456",
            "start_time": datetime(2025, 7, 31, 14, 0, 0, tzinfo=timezone.utc),
            "end_time": datetime(2025, 7, 31, 16, 0, 0, tzinfo=timezone.utc),
        }

        # Test each valid status
        valid_statuses = ["active", "cancelled", "completed"]
        for status in valid_statuses:
            reservation = Reservation(**base_data, status=status)
            assert reservation.status == status

    def test_reservation_model_missing_required_fields(self):
        """Test Reservation model validation with missing required fields"""
        # Test missing reservation_id
        with pytest.raises(ValidationError) as exc_info:
            Reservation(
                slot_id="SLOT-C3",
                user_id="USER-789",
                start_time=datetime(2025, 7, 31, 18, 0, 0, tzinfo=timezone.utc),
                end_time=datetime(2025, 7, 31, 20, 0, 0, tzinfo=timezone.utc),
                status="active",
            )
        assert "reservation_id" in str(exc_info.value)

    def test_reservation_model_invalid_data_types(self):
        """Test Reservation model with invalid data types"""
        # Test invalid datetime
        with pytest.raises(ValidationError):
            Reservation(
                reservation_id="RES-004",
                slot_id="SLOT-D4",
                user_id="USER-999",
                start_time="not-a-datetime",  # Invalid type
                end_time=datetime(2025, 7, 31, 22, 0, 0, tzinfo=timezone.utc),
                status="active",
            )

    def test_reservation_model_edge_cases(self):
        """Test Reservation model with edge cases"""
        # Test with very long IDs
        long_id = "A" * 100
        reservation = Reservation(
            reservation_id=long_id,
            slot_id="SLOT-E5",
            user_id="USER-EDGE",
            start_time=datetime(2025, 8, 1, 9, 0, 0, tzinfo=timezone.utc),
            end_time=datetime(2025, 8, 1, 11, 0, 0, tzinfo=timezone.utc),
            status="active",
        )
        assert reservation.reservation_id == long_id

    def test_reservation_model_datetime_handling(self):
        """Test Reservation model datetime field handling"""
        # Test with different timezone
        import zoneinfo

        pst_tz = zoneinfo.ZoneInfo("America/Los_Angeles")

        reservation = Reservation(
            reservation_id="RES-TZ",
            slot_id="SLOT-TZ",
            user_id="USER-TZ",
            start_time=datetime(2025, 8, 1, 10, 0, 0, tzinfo=pst_tz),
            end_time=datetime(2025, 8, 1, 12, 0, 0, tzinfo=pst_tz),
            status="active",
        )

        assert reservation.start_time.tzinfo == pst_tz
        assert reservation.end_time.tzinfo == pst_tz

    def test_reservation_status_validation(self):
        """Test that only valid status values are accepted"""
        valid_data = {
            "reservation_id": "RES-STATUS",
            "slot_id": "SLOT-STATUS",
            "user_id": "USER-STATUS",
            "start_time": datetime(2025, 8, 1, 16, 0, 0, tzinfo=timezone.utc),
            "end_time": datetime(2025, 8, 1, 18, 0, 0, tzinfo=timezone.utc),
        }

        # Test all valid statuses work
        for status in ["active", "cancelled", "completed"]:
            reservation = Reservation(**valid_data, status=status)
            assert reservation.status == status


class TestReservationBusinessLogic:
    """Test business logic and utility functions for reservations"""

    def test_reservation_duration_calculation(self):
        """Test calculating reservation duration"""
        reservation = Reservation(
            reservation_id="RES-DURATION",
            slot_id="SLOT-DUR",
            user_id="USER-DUR",
            start_time=datetime(2025, 8, 1, 10, 0, 0, tzinfo=timezone.utc),
            end_time=datetime(2025, 8, 1, 12, 30, 0, tzinfo=timezone.utc),
            status="active",
        )

        duration = reservation.end_time - reservation.start_time
        assert duration.total_seconds() == 9000  # 2.5 hours = 9000 seconds

    def test_reservation_overlap_detection(self):
        """Test detecting overlapping reservations"""
        # Create two overlapping reservations
        reservation1 = Reservation(
            reservation_id="RES-OVERLAP1",
            slot_id="SLOT-SAME",
            user_id="USER-1",
            start_time=datetime(2025, 8, 1, 10, 0, 0, tzinfo=timezone.utc),
            end_time=datetime(2025, 8, 1, 12, 0, 0, tzinfo=timezone.utc),
            status="active",
        )

        reservation2 = Reservation(
            reservation_id="RES-OVERLAP2",
            slot_id="SLOT-SAME",
            user_id="USER-2",
            start_time=datetime(2025, 8, 1, 11, 0, 0, tzinfo=timezone.utc),
            end_time=datetime(2025, 8, 1, 13, 0, 0, tzinfo=timezone.utc),
            status="active",
        )

        # Check if they overlap (same slot_id and overlapping times)
        assert reservation1.slot_id == reservation2.slot_id
        assert reservation1.start_time < reservation2.end_time
        assert reservation2.start_time < reservation1.end_time

    def test_reservation_json_serialization(self):
        """Test that reservation can be converted to JSON-like dict"""
        reservation = Reservation(
            reservation_id="RES-JSON",
            slot_id="SLOT-JSON",
            user_id="USER-JSON",
            start_time=datetime(2025, 8, 1, 14, 0, 0, tzinfo=timezone.utc),
            end_time=datetime(2025, 8, 1, 16, 0, 0, tzinfo=timezone.utc),
            status="completed",
        )

        # Convert to dict (like JSON serialization)
        reservation_dict = reservation.model_dump()

        assert reservation_dict["reservation_id"] == "RES-JSON"
        assert reservation_dict["slot_id"] == "SLOT-JSON"
        assert reservation_dict["user_id"] == "USER-JSON"
        assert reservation_dict["status"] == "completed"
        assert "start_time" in reservation_dict
        assert "end_time" in reservation_dict


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
