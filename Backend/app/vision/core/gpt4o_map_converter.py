"""
GPT-4o Vision Parking Map Converter
Intelligent parking lot map conversion using GPT-4o Vision API
"""

from typing import List, Dict, Any, Tuple
from app.vision.processors.gpt4o_detector import GPT4oDetector


class GPT4oParkingMapConverter:
    """
    GPT-4o Parking Map Converter - Uses AI vision for intelligent parking lot analysis
    """

    def __init__(
        self, grid_size: Tuple[int, int] = (10, 10), openai_api_key: str = None
    ):
        """
        Initialize GPT-4o parking map converter

        Args:
            grid_size: Grid size (rows, cols)
            openai_api_key: OpenAI API key for GPT-4o Vision
        """
        self.grid_size = grid_size
        self.gpt4o_detector = GPT4oDetector(api_key=openai_api_key)

    def convert_image_to_parking_map(
        self, image_path: str, building_name: str = "Unknown Building"
    ) -> List[Dict[str, Any]]:
        """
        Convert parking lot image to JSON format using GPT-4o Vision

        Args:
            image_path: Image path
            building_name: Building name (will be overridden by GPT-4o if detected)

        Returns:
            Parking lot map data
        """
        try:
            print("🚀 Starting GPT-4o Vision analysis...")

            # Use GPT-4o to analyze the image
            analysis = self.gpt4o_detector.analyze_parking_image(
                image_path, self.grid_size
            )

            print(
                f"🔍 GPT-4o detected: {analysis.get('analysis', {}).get('total_parking_slots', 'Unknown')} parking slots"
            )

            # Convert GPT-4o analysis to parking map format
            parking_map = self.gpt4o_detector.convert_to_parking_map_format(
                analysis, self.grid_size
            )

            # Update building name logic:
            detected_name = analysis.get("building_name", "Unknown")
            if detected_name and detected_name.lower() not in [
                "unknown",
                "unknown building",
                "",
            ]:
                final_building_name = detected_name
            else:
                final_building_name = building_name
            for level_data in parking_map:
                level_data["building"] = final_building_name
            return parking_map

        except Exception as e:
            print(f"❌ GPT-4o analysis failed: {e}")
            raise ValueError(
                f"GPT-4o parking lot image analysis failed: {str(e)}. Please check the image quality or try again."
            )

    def validate_parking_map(self, parking_map: List[Dict[str, Any]]) -> Dict[str, Any]:
        validation_result = {"is_valid": True, "errors": [], "warnings": []}
        for level_data in parking_map:
            level = level_data.get("level", 1)
            required_fields = [
                "building",
                "level",
                "size",
                "entrances",
                "exits",
                "slots",
                "corridors",
                "walls",
            ]
            for field in required_fields:
                if field not in level_data:
                    validation_result["errors"].append(
                        f"Level {level}: Missing required field '{field}'"
                    )
                    validation_result["is_valid"] = False
            slots_count = len(level_data.get("slots", []))
            if slots_count == 0:
                validation_result["warnings"].append(
                    f"Level {level}: No parking slots detected"
                )
            else:
                validation_result["warnings"].append(
                    f"Level {level}: {slots_count} parking slots detected by GPT-4o"
                )
        return validation_result
