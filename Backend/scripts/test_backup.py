#!/usr/bin/env python3
"""
Test script to verify backup functionality
"""

import os
import sys
import subprocess
import logging
from pathlib import Path

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def test_backup_system():
    """Test the backup system functionality."""
    logger.info("Testing MongoDB backup system...")

    # Test backup creation
    logger.info("1. Testing backup creation...")
    result = subprocess.run(
        ["python", "/app/scripts/backup_mongodb.py"], capture_output=True, text=True
    )

    if result.returncode != 0:
        logger.error(f"Backup creation failed: {result.stderr}")
        return False

    logger.info("✓ Backup creation test passed")

    # Test backup listing
    logger.info("2. Testing backup listing...")
    result = subprocess.run(
        ["python", "/app/scripts/backup_mongodb.py", "list"],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        logger.error(f"Backup listing failed: {result.stderr}")
        return False

    logger.info("✓ Backup listing test passed")

    # Test restore listing
    logger.info("3. Testing restore listing...")
    result = subprocess.run(
        ["python", "/app/scripts/restore_mongodb.py", "list"],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        logger.error(f"Restore listing failed: {result.stderr}")
        return False

    logger.info("✓ Restore listing test passed")

    logger.info("All backup system tests passed!")
    return True


if __name__ == "__main__":
    if test_backup_system():
        logger.info("Backup system is working correctly")
    else:
        logger.error("Backup system tests failed")
        sys.exit(1)
