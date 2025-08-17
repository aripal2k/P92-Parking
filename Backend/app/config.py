"""
Application Configuration
Manages environment variables and application settings
"""

import os
from typing import Optional


class Settings:
    """
    Application settings and configuration
    """

    def __init__(self):
        # OpenAI API Key for GPT-4o Vision
        self.openai_api_key: Optional[str] = os.getenv("OPENAI_API_KEY", "")

        # Database settings
        self.mongodb_url: str = os.getenv("MONGODB_URL", "mongodb://mongo:27017")
        self.database_name: str = os.getenv("DATABASE_NAME", "parking_app")

        # Redis cache settings
        self.redis_url: str = os.getenv("REDIS_URL", "redis://redis:6379")
        self.cache_ttl: int = int(os.getenv("CACHE_TTL", "300"))  # 5 minutes default

        # Application settings
        self.app_name: str = "AutoSpot Backend API"
        self.version: str = "2.0.0"
        self.debug: bool = os.getenv("DEBUG", "false").lower() == "true"

        # Vision API settings
        self.default_grid_rows: int = int(os.getenv("DEFAULT_GRID_ROWS", "10"))
        self.default_grid_cols: int = int(os.getenv("DEFAULT_GRID_COLS", "10"))
        self.max_file_size_mb: int = int(os.getenv("MAX_FILE_SIZE_MB", "10"))

        # Carbon emissions settings:
        # source: https://www.ntc.gov.au/light-vehicle-emissions-intensity-australia#:~:text=International%20comparison%3A%20In%202023%2C%20the,g%2Fkm%20for%20similar%20vehicles.
        self.co2_emissions_per_meter: float = float(
            os.getenv("CO2_EMISSIONS_PER_METER", "0.194")
        )  # grams CO2 per meter for typical passenger car in Australia
        # distance a car would travel randomly in a parking lot without AutoSpot
        self.baseline_search_distance: float = float(
            os.getenv("BASELINE_SEARCH_DISTANCE", "100.0")
        )  # meters - average distance without guidance

    def get_openai_api_key(self) -> str:
        """
        Get OpenAI API Key with validation

        Returns:
            OpenAI API Key

        Raises:
            ValueError: If API key is not configured
        """
        if not self.openai_api_key:
            raise ValueError(
                "OpenAI API Key not configured. Please set OPENAI_API_KEY environment variable."
            )
        return self.openai_api_key

    def is_openai_configured(self) -> bool:
        """
        Check if OpenAI API Key is configured

        Returns:
            True if API key is available
        """
        return bool(self.openai_api_key)


# Global settings instance
settings = Settings()

# Export for easy import
__all__ = ["settings", "Settings"] 