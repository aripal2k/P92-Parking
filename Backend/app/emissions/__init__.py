"""
Carbon Emissions Estimation Module

This module provides API endpoints and utilities for calculating
carbon emissions saved by using efficient parking routing.
"""

from .router import router as emissions_router

__all__ = ["emissions_router"]
