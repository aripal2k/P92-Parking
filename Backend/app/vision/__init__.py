"""
Vision Package - Parking Lot Image Recognition and Processing
Provides unified interfaces for image processing, text recognition, and map conversion
"""

from .core.gpt4o_map_converter import GPT4oParkingMapConverter
from .processors.gpt4o_detector import GPT4oDetector

# Version information
__version__ = "1.0.0"
__author__ = "AutoSpot Team"

# Main public classes
__all__ = ["GPT4oParkingMapConverter", "GPT4oDetector", "GPT4oVisionAPI"]


class GPT4oVisionAPI:
    """
    GPT-4o Vision API interface for intelligent parking lot image analysis
    """

    def __init__(self, grid_size=(10, 10), openai_api_key=None):
        """
        Initialize GPT-4o Vision API

        Args:
            grid_size: Grid size (rows, cols)
            openai_api_key: OpenAI API Key for GPT-4o Vision
        """
        self.grid_size = grid_size
        self.converter = GPT4oParkingMapConverter(
            grid_size=grid_size, openai_api_key=openai_api_key
        )

    def process_parking_image(
        self, image_path: str, building_name: str = "Unknown Building"
    ):
        """
        Process parking lot image using GPT-4o Vision

        Args:
            image_path: Image file path
            building_name: Building name

        Returns:
            Dictionary containing map data and validation results
        """
        # Convert image using GPT-4o
        parking_map = self.converter.convert_image_to_parking_map(
            image_path, building_name
        )

        # Validate results
        validation = self.converter.validate_parking_map(parking_map)

        return {
            "parking_map": parking_map,
            "validation": validation,
            "metadata": {
                "grid_size": self.grid_size,
                "building_name": building_name,
                "ai_engine": "GPT-4o Vision",
            },
        }

    def analyze_image_only(self, image_path: str):
        """
        Analyze image using GPT-4o Vision without full conversion

        Args:
            image_path: Image file path

        Returns:
            GPT-4o analysis results
        """
        analysis = self.converter.gpt4o_detector.analyze_parking_image(
            image_path, self.grid_size
        )

        return {
            "gpt4o_analysis": analysis,
            "analysis_summary": {
                "total_parking_slots": analysis.get("analysis", {}).get(
                    "total_parking_slots", "Unknown"
                ),
                "layout_type": analysis.get("analysis", {}).get(
                    "layout_type", "Unknown"
                ),
                "complexity": analysis.get("analysis", {}).get("complexity", "Unknown"),
                "building_name": analysis.get("building_name", "Unknown"),
                "description": analysis.get("description", "No description available"),
            },
        }

    def get_supported_formats(self):
        """Get supported image formats"""
        return [".jpg", ".jpeg", ".png", ".bmp"]

    def get_version_info(self):
        """Get version information"""
        return {
            "version": __version__,
            "author": __author__,
            "ai_engine": "GPT-4o Vision",
            "supported_formats": self.get_supported_formats(),
            "dependencies": ["openai", "pillow", "numpy"],
        }
