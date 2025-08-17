#!/usr/bin/env python3
"""
Create CloudWatch Dashboard for AutoSpot Parking System
This script creates a comprehensive dashboard to monitor system health and business metrics
"""

import boto3
import json
import os
import sys
from datetime import datetime


class DashboardCreator:
    def __init__(self):
        self.client = boto3.client(
            "cloudwatch",
            region_name=os.getenv("AWS_DEFAULT_REGION", "ap-southeast-2"),
            aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
            aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
        )
        self.namespace = "AutoSpot/Backend"
        self.dashboard_name = "AutoSpot-Monitoring"

    def create_dashboard(self):
        """Create the CloudWatch dashboard with all metrics"""
        dashboard_body = {
            "widgets": [
                # API Performance Overview (Top Row)
                {
                    "type": "metric",
                    "x": 0,
                    "y": 0,
                    "width": 12,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [
                                self.namespace,
                                "APIRequests",
                                {"stat": "Sum", "period": 300},
                            ]
                        ],
                        "view": "timeSeries",
                        "stacked": False,
                        "region": "ap-southeast-2",
                        "title": "API Request Volume",
                        "period": 300,
                        "yAxis": {"left": {"label": "Requests"}},
                    },
                },
                {
                    "type": "metric",
                    "x": 12,
                    "y": 0,
                    "width": 12,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [
                                self.namespace,
                                "APIResponseTime",
                                {"stat": "Average", "period": 300},
                            ],
                            ["...", {"stat": "p99", "period": 300}],
                        ],
                        "view": "timeSeries",
                        "stacked": False,
                        "region": "ap-southeast-2",
                        "title": "API Response Time",
                        "period": 300,
                        "yAxis": {"left": {"label": "Milliseconds"}},
                    },
                },
                # Parking Occupancy (Second Row)
                {
                    "type": "metric",
                    "x": 0,
                    "y": 6,
                    "width": 8,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [
                                self.namespace,
                                "ParkingOccupancyRate",
                                {"stat": "Average", "period": 300},
                            ]
                        ],
                        "view": "singleValue",
                        "region": "ap-southeast-2",
                        "title": "Parking Occupancy Rate",
                        "period": 300,
                    },
                },
                {
                    "type": "metric",
                    "x": 8,
                    "y": 6,
                    "width": 8,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [
                                self.namespace,
                                "ParkingOccupancy",
                                {"stat": "Sum", "period": 300},
                            ],
                            [".", "ParkingCapacity", {"stat": "Sum", "period": 300}],
                        ],
                        "view": "timeSeries",
                        "stacked": False,
                        "region": "ap-southeast-2",
                        "title": "Occupied vs Total Spots",
                        "period": 300,
                        "yAxis": {"left": {"label": "Parking Spots"}},
                    },
                },
                {
                    "type": "metric",
                    "x": 16,
                    "y": 6,
                    "width": 8,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [self.namespace, "Revenue", {"stat": "Sum", "period": 300}]
                        ],
                        "view": "singleValue",
                        "region": "ap-southeast-2",
                        "title": "Revenue (Last 5 min)",
                        "period": 300,
                        "setPeriodToTimeRange": True,
                    },
                },
                # User Activity (Third Row)
                {
                    "type": "metric",
                    "x": 0,
                    "y": 12,
                    "width": 12,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [
                                self.namespace,
                                "AuthEvents",
                                "EventType",
                                "login",
                                {"stat": "Sum", "period": 300},
                            ],
                            ["...", "register", {"stat": "Sum", "period": 300}],
                            ["...", "logout", {"stat": "Sum", "period": 300}],
                        ],
                        "view": "timeSeries",
                        "stacked": False,
                        "region": "ap-southeast-2",
                        "title": "User Authentication Events",
                        "period": 300,
                    },
                },
                {
                    "type": "metric",
                    "x": 12,
                    "y": 12,
                    "width": 12,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [self.namespace, "QRScans", {"stat": "Sum", "period": 300}]
                        ],
                        "view": "timeSeries",
                        "stacked": True,
                        "region": "ap-southeast-2",
                        "title": "QR Code Scans",
                        "period": 300,
                    },
                },
                # API Endpoints Performance (Fourth Row)
                {
                    "type": "metric",
                    "x": 0,
                    "y": 18,
                    "width": 24,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [self.namespace, "APIRequests", {"stat": "Sum"}],
                            [".", "APIResponseTime", {"stat": "Average"}],
                        ],
                        "view": "table",
                        "stacked": False,
                        "region": "ap-southeast-2",
                        "title": "API Endpoints Summary",
                        "period": 300,
                        "setPeriodToTimeRange": True,
                    },
                },
                # Database Performance (Fifth Row)
                {
                    "type": "metric",
                    "x": 0,
                    "y": 24,
                    "width": 12,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [
                                self.namespace,
                                "DatabaseOperations",
                                {"stat": "Sum", "period": 300},
                            ]
                        ],
                        "view": "timeSeries",
                        "stacked": False,
                        "region": "ap-southeast-2",
                        "title": "Database Operations",
                        "period": 300,
                    },
                },
                {
                    "type": "metric",
                    "x": 12,
                    "y": 24,
                    "width": 12,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [
                                self.namespace,
                                "DatabaseOperationDuration",
                                {"stat": "Average", "period": 300},
                            ]
                        ],
                        "view": "timeSeries",
                        "stacked": False,
                        "region": "ap-southeast-2",
                        "title": "Database Operation Duration",
                        "period": 300,
                        "yAxis": {"left": {"label": "Milliseconds"}},
                    },
                },
                # Redis Cache Performance (Sixth Row)
                {
                    "type": "metric",
                    "x": 0,
                    "y": 30,
                    "width": 8,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [
                                self.namespace,
                                "CacheOperation",
                                "Operation",
                                "get",
                                "Hit",
                                "True",
                                {"stat": "Sum", "period": 300},
                            ],
                            ["...", "False", {"stat": "Sum", "period": 300}],
                        ],
                        "view": "timeSeries",
                        "stacked": False,
                        "region": "ap-southeast-2",
                        "title": "Cache Hits vs Misses",
                        "period": 300,
                    },
                },
                {
                    "type": "metric",
                    "x": 8,
                    "y": 30,
                    "width": 8,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [
                                {
                                    "expression": "m1/(m1+m2)*100",
                                    "label": "Cache Hit Rate %",
                                    "id": "e1",
                                }
                            ],
                            [
                                self.namespace,
                                "CacheOperation",
                                "Operation",
                                "get",
                                "Hit",
                                "True",
                                {
                                    "stat": "Sum",
                                    "period": 300,
                                    "id": "m1",
                                    "visible": False,
                                },
                            ],
                            [
                                "...",
                                "False",
                                {
                                    "stat": "Sum",
                                    "period": 300,
                                    "id": "m2",
                                    "visible": False,
                                },
                            ],
                        ],
                        "view": "singleValue",
                        "region": "ap-southeast-2",
                        "title": "Cache Hit Rate",
                        "period": 300,
                    },
                },
                {
                    "type": "metric",
                    "x": 16,
                    "y": 30,
                    "width": 8,
                    "height": 6,
                    "properties": {
                        "metrics": [
                            [
                                self.namespace,
                                "CacheOperationDuration",
                                "Operation",
                                "get",
                                {"stat": "Average", "period": 300},
                            ],
                            ["...", "set", {"stat": "Average", "period": 300}],
                        ],
                        "view": "timeSeries",
                        "stacked": False,
                        "region": "ap-southeast-2",
                        "title": "Cache Operation Duration",
                        "period": 300,
                        "yAxis": {"left": {"label": "Milliseconds"}},
                    },
                },
            ]
        }

        try:
            response = self.client.put_dashboard(
                DashboardName=self.dashboard_name,
                DashboardBody=json.dumps(dashboard_body),
            )
            print(f"✅ Dashboard '{self.dashboard_name}' created successfully!")
            print(
                f"📊 View it at: https://ap-southeast-2.console.aws.amazon.com/cloudwatch/home?region=ap-southeast-2#dashboards:name={self.dashboard_name}"
            )
            return True
        except Exception as e:
            print(f"❌ Failed to create dashboard: {str(e)}")
            return False

    def create_alarms(self):
        """Create CloudWatch alarms for critical metrics"""
        alarms = [
            {
                "name": "AutoSpot-HighParkingOccupancy",
                "description": "Alert when parking occupancy exceeds 90%",
                "metric_name": "ParkingOccupancyRate",
                "threshold": 90,
                "comparison": "GreaterThanThreshold",
                "evaluation_periods": 2,
                "period": 300,
            },
            {
                "name": "AutoSpot-HighAPIResponseTime",
                "description": "Alert when API response time exceeds 1000ms",
                "metric_name": "APIResponseTime",
                "statistic": "Average",
                "threshold": 1000,
                "comparison": "GreaterThanThreshold",
                "evaluation_periods": 2,
                "period": 300,
            },
            {
                "name": "AutoSpot-APIErrors",
                "description": "Alert on high API error rate",
                "metric_name": "APIRequests",
                "dimensions": [{"Name": "StatusCode", "Value": "500"}],
                "threshold": 10,
                "comparison": "GreaterThanThreshold",
                "evaluation_periods": 1,
                "period": 300,
            },
        ]

        for alarm in alarms:
            try:
                dimensions = alarm.get("dimensions", [])

                self.client.put_metric_alarm(
                    AlarmName=alarm["name"],
                    ComparisonOperator=alarm["comparison"],
                    EvaluationPeriods=alarm["evaluation_periods"],
                    MetricName=alarm["metric_name"],
                    Namespace=self.namespace,
                    Period=alarm["period"],
                    Statistic=alarm.get("statistic", "Sum"),
                    Threshold=alarm["threshold"],
                    ActionsEnabled=True,
                    AlarmDescription=alarm["description"],
                    Dimensions=dimensions,
                )
                print(f"✅ Alarm '{alarm['name']}' created successfully!")
            except Exception as e:
                print(f"⚠️  Failed to create alarm '{alarm['name']}': {str(e)}")


def main():
    if not os.getenv("AWS_ACCESS_KEY_ID") or not os.getenv("AWS_SECRET_ACCESS_KEY"):
        print(
            "❌ AWS credentials not found. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables."
        )
        sys.exit(1)

    creator = DashboardCreator()

    print("🚀 Creating CloudWatch Dashboard for AutoSpot...")
    if creator.create_dashboard():
        print("\n🔔 Creating CloudWatch Alarms...")
        creator.create_alarms()
        print("\n✨ Dashboard setup complete!")
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
