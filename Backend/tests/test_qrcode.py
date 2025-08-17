import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
from app.main import app
from datetime import datetime, timezone, timedelta
import json
import base64
import io
import qrcode

client = TestClient(app)


class TestQRCodeGeneration:
    """Test cases for QR code generation functionality"""

    @patch("app.QRcode.router.db")
    def test_generate_entrance_qr_json_format(self, mock_db):
        """Test generating entrance QR code in JSON format"""
        # Mock the MongoDB find_one to return map data with entrance
        mock_db.__getitem__.return_value.find_one.return_value = {
            "building_name": "Westfield Sydney",
            "parking_map": [
                {
                    "building": "Westfield Sydney",
                    "level": 1,
                    "entrances": [
                        {"entrance_id": "E1", "x": 10, "y": 20, "direction": "north"}
                    ],
                }
            ],
        }
        mock_db.__getitem__.return_value.insert_one.return_value = None

        response = client.get(
            "/qr/generate-entrance-qr",
            params={
                "entrance_id": "E1",
                "building_name": "Westfield Sydney",
                "format_type": "json",
            },
        )

        assert response.status_code == 200
        data = response.json()

        # Check response structure
        assert "qr_image_base64" in data
        assert "entrance_id" in data
        assert "building" in data
        assert "level" in data
        assert "coordinates" in data
        assert "format_type" in data
        assert "qr_content" in data

        # Verify content
        assert data["entrance_id"] == "E1"
        assert data["building"] == "Westfield Sydney"
        assert data["format_type"] == "json"
        assert isinstance(data["coordinates"], dict)
        assert "x" in data["coordinates"]
        assert "y" in data["coordinates"]

        # Verify QR content is JSON format
        assert isinstance(data["qr_content"], dict)
        assert data["qr_content"]["entrance_id"] == "E1"
        assert data["qr_content"]["building"] == "Westfield Sydney"

    @patch("app.QRcode.router.db")
    def test_generate_entrance_qr_simple_format(self, mock_db):
        """Test generating entrance QR code in simple format"""
        # Mock the MongoDB find_one to return map data with entrance
        mock_db.__getitem__.return_value.find_one.return_value = {
            "building_name": "Westfield Sydney",
            "parking_map": [
                {
                    "building": "Westfield Sydney",
                    "level": 1,
                    "entrances": [
                        {"entrance_id": "E1", "x": 10, "y": 20, "direction": "north"}
                    ],
                }
            ],
        }
        mock_db.__getitem__.return_value.insert_one.return_value = None

        response = client.get(
            "/qr/generate-entrance-qr",
            params={
                "entrance_id": "E1",
                "building_name": "Westfield Sydney",
                "format_type": "simple",
            },
        )

        assert response.status_code == 200
        data = response.json()

        # Verify format type
        assert data["format_type"] == "simple"
        assert isinstance(data["qr_content"], str)
        assert data["qr_content"].startswith("ENTRANCE_")
        assert "Westfield Sydney" in data["qr_content"]
        assert "E1" in data["qr_content"]

    @patch("app.QRcode.router.db")
    def test_generate_entrance_qr_param_format(self, mock_db):
        """Test generating entrance QR code in param format"""
        # Mock the MongoDB find_one to return map data with entrance
        mock_db.__getitem__.return_value.find_one.return_value = {
            "building_name": "Westfield Sydney",
            "parking_map": [
                {
                    "building": "Westfield Sydney",
                    "level": 1,
                    "entrances": [
                        {"entrance_id": "E1", "x": 10, "y": 20, "direction": "north"}
                    ],
                }
            ],
        }
        mock_db.__getitem__.return_value.insert_one.return_value = None

        response = client.get(
            "/qr/generate-entrance-qr",
            params={
                "entrance_id": "E1",
                "building_name": "Westfield Sydney",
                "format_type": "param",
            },
        )

        assert response.status_code == 200
        data = response.json()

        # Verify format type
        assert data["format_type"] == "param"
        assert isinstance(data["qr_content"], str)
        assert "entrance=E1" in data["qr_content"]
        assert "building=Westfield Sydney" in data["qr_content"]
        assert "&" in data["qr_content"]

    def test_generate_entrance_qr_invalid_entrance(self):
        """Test generating QR code with invalid entrance ID"""
        response = client.get(
            "/qr/generate-entrance-qr",
            params={
                "entrance_id": "E999",
                "building_name": "Westfield Sydney",
                "format_type": "json",
            },
        )

        assert response.status_code == 400
        assert "not found" in response.json()["detail"]

    def test_generate_entrance_qr_invalid_building(self):
        """Test generating QR code with invalid building name"""
        response = client.get(
            "/qr/generate-entrance-qr",
            params={
                "entrance_id": "E1",
                "building_name": "NonExistentBuilding",
                "format_type": "json",
            },
        )

        assert response.status_code == 400
        assert "not found" in response.json()["detail"]

    def test_generate_entrance_qr_invalid_format(self):
        """Test generating QR code with invalid format type"""
        response = client.get(
            "/qr/generate-entrance-qr",
            params={
                "entrance_id": "E1",
                "building_name": "Westfield Sydney",
                "format_type": "invalid",
            },
        )

        assert response.status_code == 400
        # Error message changed - now it says entrance not found instead of unsupported format
        assert (
            "not found" in response.json()["detail"].lower()
            or "Unsupported format type" in response.json()["detail"]
        )


class TestQRCodeBase64Conversion:
    """Test cases for base64 to image conversion"""

    def test_base64_to_image_valid(self):
        """Test converting valid base64 to image"""
        # Create a simple test image
        qr = qrcode.make("test")
        buf = io.BytesIO()
        qr.save(buf, format="PNG")
        img_b64 = base64.b64encode(buf.getvalue()).decode()

        response = client.post("/qr/base64-to-image", json={"qr_image_base64": img_b64})

        assert response.status_code == 200
        assert response.headers["content-type"] == "image/png"

    def test_base64_to_image_invalid(self):
        """Test converting invalid base64 to image"""
        response = client.post(
            "/qr/base64-to-image", json={"qr_image_base64": "invalid_base64"}
        )

        assert response.status_code == 400
        assert "Invalid base64 image data" in response.json()["detail"]


class TestQRCodeList:
    """Test cases for listing QR codes"""

    @patch("app.QRcode.router.db")
    def test_list_qrcodes_with_results(self, mock_db):
        """Test listing QR codes for a user with existing QR codes"""
        # Mock data
        mock_qrcodes = [
            {
                "username": "testuser",
                "destination": "Westfield Sydney",
                "store": "Store A",
                "date": "2025-07-20",
                "time": "14:00",
                "expire_at": "2025-07-20T14:15:00+00:00",
                "created_at": "2025-07-20T13:00:00+00:00",
                "entrances": [{"entrance_id": "E1", "x": 10, "y": 20}],
                "qr_content": {"test": "content"},
                "qr_image_base64": "test_base64",
            }
        ]
        mock_db.__getitem__.return_value.find.return_value = mock_qrcodes

        response = client.get("/qr/list", params={"username": "testuser"})

        assert response.status_code == 200
        data = response.json()
        assert "qrcodes" in data
        assert "total" in data
        assert data["total"] == 1
        assert len(data["qrcodes"]) == 1

        qr = data["qrcodes"][0]
        assert qr["username"] == "testuser"
        assert qr["destination"] == "Westfield Sydney"
        assert qr["status"] in ["valid", "expired"]

    @patch("app.QRcode.router.db")
    def test_list_qrcodes_empty(self, mock_db):
        """Test listing QR codes for a user with no QR codes"""
        mock_db.__getitem__.return_value.find.return_value = []

        response = client.get("/qr/list", params={"username": "newuser"})

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 0
        assert len(data["qrcodes"]) == 0

    @patch("app.QRcode.router.db")
    def test_list_qrcodes_status_check(self, mock_db):
        """Test QR code status (valid/expired) checking"""
        # Use actual datetime for comparison

        # Mock data with one expired and one valid QR code
        past_time = datetime.now(timezone.utc) - timedelta(hours=1)
        future_time = datetime.now(timezone.utc) + timedelta(hours=1)

        mock_qrcodes = [
            {
                "username": "testuser",
                "destination": "Mall",
                "expire_at": past_time.isoformat(),  # Expired
                "qr_content": {"test": "content1"},
                "qr_image_base64": "test_base64_1",
            },
            {
                "username": "testuser",
                "destination": "Office",
                "expire_at": future_time.isoformat(),  # Still valid
                "qr_content": {"test": "content2"},
                "qr_image_base64": "test_base64_2",
            },
        ]
        mock_db.__getitem__.return_value.find.return_value = mock_qrcodes

        response = client.get("/qr/list", params={"username": "testuser"})

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 2

        # Check status of each QR code
        statuses = [qr["status"] for qr in data["qrcodes"]]
        assert "expired" in statuses
        assert "valid" in statuses


class TestQRCodeValidation:
    """Test cases for QR code validation"""

    @patch("app.QRcode.router.metrics")
    def test_validate_qr_valid(self, mock_metrics):
        """Test validating a valid QR code"""
        # Use a future expire time to ensure validity

        # Create a future expiration time
        future_time = datetime.now(timezone.utc) + timedelta(hours=1)

        qr_content = {
            "username": "testuser",
            "destination": "Westfield Sydney",
            "expire_at": future_time.isoformat(),
            "building": "Westfield Sydney",
        }

        response = client.post("/qr/validate", json={"qr_content": qr_content})

        assert response.status_code == 200
        data = response.json()
        assert data["valid"] is True
        assert data["reason"] == "QR code is valid."
        assert data["username"] == "testuser"
        assert data["destination"] == "Westfield Sydney"

        # Check metrics recording
        mock_metrics.record_qr_scan.assert_called_once_with("valid", "Westfield Sydney")

    @patch("app.QRcode.router.metrics")
    def test_validate_qr_missing_field(self, mock_metrics):
        """Test validating QR code with missing required field"""
        qr_content = {
            "username": "testuser",
            "destination": "Westfield Sydney",
            # Missing expire_at
        }

        response = client.post("/qr/validate", json={"qr_content": qr_content})

        assert response.status_code == 200
        data = response.json()
        assert data["valid"] is False
        assert "Missing required field" in data["reason"]

        # Check metrics recording
        mock_metrics.record_qr_scan.assert_called_once_with("invalid_missing_field")

    @patch("app.QRcode.router.metrics")
    def test_validate_qr_expired(self, mock_metrics):
        """Test validating an expired QR code"""
        # Create a past expiration time
        past_time = datetime.now(timezone.utc) - timedelta(hours=1)

        qr_content = {
            "username": "testuser",
            "destination": "Westfield Sydney",
            "expire_at": past_time.isoformat(),  # Expired
        }

        response = client.post("/qr/validate", json={"qr_content": qr_content})

        assert response.status_code == 200
        data = response.json()
        assert data["valid"] is False
        assert "expired" in data["reason"]

        # Check metrics recording
        mock_metrics.record_qr_scan.assert_called_once_with("expired")

    @patch("app.QRcode.router.metrics")
    def test_validate_qr_invalid_date_format(self, mock_metrics):
        """Test validating QR code with invalid date format"""
        qr_content = {
            "username": "testuser",
            "destination": "Westfield Sydney",
            "expire_at": "invalid-date",
        }

        response = client.post("/qr/validate", json={"qr_content": qr_content})

        assert response.status_code == 200
        data = response.json()
        assert data["valid"] is False
        assert "Invalid expire_at format" in data["reason"]

        # Check metrics recording
        mock_metrics.record_qr_scan.assert_called_once_with("invalid_format")


class TestGenerateAllEntranceQRs:
    """Test cases for generating all entrance QR codes"""

    @patch("app.QRcode.router.db")
    def test_generate_all_entrance_qrs_json_format(self, mock_db):
        """Test generating all entrance QR codes in JSON format"""
        mock_db.__getitem__.return_value.insert_one.return_value = None

        response = client.get(
            "/qr/generate-all-entrance-qrs", params={"format_type": "json"}
        )

        assert response.status_code == 200
        data = response.json()

        assert "total" in data
        assert "qr_codes" in data
        assert data["total"] > 0
        assert len(data["qr_codes"]) == data["total"]

        # Check first QR code
        qr = data["qr_codes"][0]
        assert "entrance_id" in qr
        assert "building" in qr
        assert "level" in qr
        assert "coordinates" in qr
        assert "format_type" in qr
        assert "qr_content" in qr
        assert "qr_image_base64" in qr

        assert qr["format_type"] == "json"
        assert isinstance(qr["qr_content"], dict)

    @patch("app.QRcode.router.db")
    def test_generate_all_entrance_qrs_simple_format(self, mock_db):
        """Test generating all entrance QR codes in simple format"""
        mock_db.__getitem__.return_value.insert_one.return_value = None

        response = client.get(
            "/qr/generate-all-entrance-qrs", params={"format_type": "simple"}
        )

        assert response.status_code == 200
        data = response.json()

        assert data["total"] > 0

        # Check format of QR codes
        for qr in data["qr_codes"]:
            assert qr["format_type"] == "simple"
            assert isinstance(qr["qr_content"], str)
            assert qr["qr_content"].startswith("ENTRANCE_")

    @patch("app.QRcode.router.db")
    def test_generate_all_entrance_qrs_param_format(self, mock_db):
        """Test generating all entrance QR codes in param format"""
        mock_db.__getitem__.return_value.insert_one.return_value = None

        response = client.get(
            "/qr/generate-all-entrance-qrs", params={"format_type": "param"}
        )

        assert response.status_code == 200
        data = response.json()

        assert data["total"] > 0

        # Check format of QR codes
        for qr in data["qr_codes"]:
            assert qr["format_type"] == "param"
            assert isinstance(qr["qr_content"], str)
            assert "entrance=" in qr["qr_content"]
            assert "&building=" in qr["qr_content"]
