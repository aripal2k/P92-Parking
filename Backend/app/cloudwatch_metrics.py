import boto3
import logging
import os
from datetime import datetime
from typing import Dict, Any


class CloudWatchMetrics:
    def __init__(self):
        self.client = None
        self.namespace = "AutoSpot/Backend"

        if os.getenv("AWS_ACCESS_KEY_ID") and os.getenv("AWS_SECRET_ACCESS_KEY"):
            try:
                self.client = boto3.client(
                    "cloudwatch",
                    region_name=os.getenv("AWS_DEFAULT_REGION", "ap-southeast-2"),
                    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
                    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
                )
                logging.info("CloudWatch metrics client initialized successfully")
            except Exception as e:
                logging.error(f"Failed to initialize CloudWatch metrics client: {e}")
                self.client = None
        else:
            logging.info(
                "AWS credentials not found, metrics will not be sent to CloudWatch"
            )

    def put_metric(
        self,
        metric_name: str,
        value: float,
        unit: str = "Count",
        dimensions: Dict[str, str] = None,
    ):
        """Send a metric to CloudWatch"""
        if not self.client:
            return

        try:
            metric_data = {
                "MetricName": metric_name,
                "Value": value,
                "Unit": unit,
                "Timestamp": datetime.utcnow(),
            }

            if dimensions:
                metric_data["Dimensions"] = [
                    {"Name": key, "Value": value} for key, value in dimensions.items()
                ]

            self.client.put_metric_data(
                Namespace=self.namespace, MetricData=[metric_data]
            )

            logging.debug(f"Metric sent: {metric_name} = {value}")

        except Exception as e:
            logging.error(f"Failed to send metric {metric_name}: {e}")

    def increment_counter(self, metric_name: str, dimensions: Dict[str, str] = None):
        """Increment a counter metric"""
        self.put_metric(metric_name, 1, "Count", dimensions)

    def record_api_call(
        self, endpoint: str, method: str, status_code: int, response_time: float = None
    ):
        """Record API call metrics"""
        dimensions = {
            "Endpoint": endpoint,
            "Method": method,
            "StatusCode": str(status_code),
        }

        # Count of API calls
        self.increment_counter("APIRequests", dimensions)

        # Record response time if provided
        if response_time is not None:
            self.put_metric(
                "APIResponseTime", response_time, "Milliseconds", dimensions
            )

    def record_auth_event(self, event_type: str, success: bool):
        """Record authentication events"""
        dimensions = {"EventType": event_type, "Success": str(success)}
        self.increment_counter("AuthEvents", dimensions)

    def record_database_operation(
        self, operation: str, collection: str, duration: float = None
    ):
        """Record database operation metrics"""
        dimensions = {"Operation": operation, "Collection": collection}

        self.increment_counter("DatabaseOperations", dimensions)

        if duration is not None:
            self.put_metric(
                "DatabaseOperationDuration", duration, "Milliseconds", dimensions
            )

    def record_parking_event(self, event_type: str, lot_id: str = None):
        """Record parking-related events"""
        dimensions = {"EventType": event_type}
        if lot_id:
            dimensions["LotID"] = lot_id
        self.increment_counter("ParkingEvents", dimensions)

    def record_parking_occupancy(self, lot_id: str, occupied: int, total: int):
        """Record parking lot occupancy"""
        occupancy_rate = (occupied / total * 100) if total > 0 else 0
        dimensions = {"LotID": lot_id}

        self.put_metric("ParkingOccupancy", occupied, "Count", dimensions)
        self.put_metric("ParkingCapacity", total, "Count", dimensions)
        self.put_metric("ParkingOccupancyRate", occupancy_rate, "Percent", dimensions)

    def record_revenue(self, amount: float, payment_type: str = None):
        """Record revenue metrics"""
        dimensions = {}
        if payment_type:
            dimensions["PaymentType"] = payment_type
        self.put_metric("Revenue", amount, "None", dimensions)

    def record_qr_scan(self, scan_result: str, lot_id: str = None):
        """Record QR code scan events"""
        dimensions = {"Result": scan_result}
        if lot_id:
            dimensions["LotID"] = lot_id
        self.increment_counter("QRScans", dimensions)

    def record_user_activity(self, activity_type: str, user_type: str = "user"):
        """Record user activity metrics"""
        dimensions = {"ActivityType": activity_type, "UserType": user_type}
        self.increment_counter("UserActivity", dimensions)


# Global metrics instance
metrics = CloudWatchMetrics()
