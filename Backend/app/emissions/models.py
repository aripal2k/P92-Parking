"""
Emissions data models for MongoDB storage
"""

from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from datetime import datetime


class EmissionRecord(BaseModel):
    """
    Model for storing emission calculation data in MongoDB
    """

    username: Optional[str] = Field(None, description="Username (if available)")
    session_id: Optional[str] = Field(None, description="Associated parking session ID")

    # Route information
    route_distance: float = Field(..., description="Actual distance traveled in meters")
    baseline_distance: float = Field(
        ..., description="Baseline search distance in meters"
    )

    # Emissions calculations
    emissions_factor: float = Field(
        ..., description="CO2 emissions factor in grams per meter"
    )
    actual_emissions: float = Field(..., description="Actual CO2 emissions in grams")
    baseline_emissions: float = Field(
        ..., description="Baseline CO2 emissions in grams"
    )
    emissions_saved: float = Field(..., description="CO2 emissions saved in grams")
    percentage_saved: float = Field(..., description="Percentage of emissions saved")

    # Metadata
    calculation_method: str = Field(
        ..., description="Method used for calculation (static/dynamic)"
    )
    map_info: Optional[Dict[str, Any]] = Field(
        None, description="Associated map information"
    )
    journey_details: Optional[Dict[str, Any]] = Field(
        None, description="Journey details if applicable"
    )
    endpoint_used: str = Field(..., description="API endpoint used for calculation")

    # Timestamps
    created_at: datetime = Field(
        default_factory=datetime.utcnow, description="Record creation timestamp"
    )

    class Config:
        allow_population_by_field_name = True
        arbitrary_types_allowed = True


class EmissionSummary(BaseModel):
    """
    Model for emission summary statistics
    """

    total_records: int
    total_emissions_saved: float
    total_distance_optimized: float
    average_percentage_saved: float


class EmissionHistoryQuery(BaseModel):
    """
    Model for querying emission history
    """

    username: Optional[str] = None
    session_id: Optional[str] = None
    calculation_method: Optional[str] = None
    limit: Optional[int] = Field(50, le=100)
