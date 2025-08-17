#!/usr/bin/env python3
"""
MongoDB Restore Script for AutoSpot
Restores MongoDB database from compressed backup files.
"""

import os
import sys
import subprocess
import logging
import shutil
import tarfile
from pathlib import Path

# Setup logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class MongoRestore:
    def __init__(self):
        self.mongodb_uri = os.getenv("MONGODB_URI", "mongodb://mongo:27017")
        self.database_name = os.getenv("DATABASE_NAME", "parking_app")
        self.backup_dir = Path("/app/backups")

    def list_backups(self):
        """List all available backups."""
        backups = list(self.backup_dir.glob("autospot_backup_*.tar.gz"))
        backups.sort(key=lambda x: x.stat().st_mtime, reverse=True)

        if not backups:
            logger.info("No backups found.")
            return []

        logger.info("Available backups:")
        for i, backup in enumerate(backups, 1):
            file_time = backup.stat().st_mtime
            file_size = backup.stat().st_size / (1024 * 1024)
            logger.info(f"  {i}. {backup.name} ({file_size:.2f} MB)")

        return backups

    def restore_backup(self, backup_filename):
        """Restore database from a specific backup file."""
        backup_path = self.backup_dir / backup_filename

        if not backup_path.exists():
            logger.error(f"Backup file not found: {backup_filename}")
            return False

        logger.info(f"Starting restore from: {backup_filename}")

        try:
            # Extract backup
            temp_dir = self.backup_dir / "temp_restore"
            temp_dir.mkdir(exist_ok=True)

            with tarfile.open(backup_path, "r:gz") as tar:
                tar.extractall(temp_dir)

            # Find the database dump directory
            db_dump_dir = temp_dir / self.database_name

            if not db_dump_dir.exists():
                logger.error(f"Database dump directory not found: {db_dump_dir}")
                return False

            # Create mongorestore command
            cmd = [
                "mongorestore",
                "--uri",
                self.mongodb_uri,
                "--db",
                self.database_name,
                "--drop",  # Drop existing collections before restore
                str(db_dump_dir),
            ]

            # Execute mongorestore
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode != 0:
                logger.error(f"Mongorestore failed: {result.stderr}")
                return False

            logger.info("Restore completed successfully")
            return True

        except Exception as e:
            logger.error(f"Restore failed: {str(e)}")
            return False

        finally:
            # Clean up temp directory
            if temp_dir.exists():
                shutil.rmtree(temp_dir)


def main():
    restore = MongoRestore()

    if len(sys.argv) < 2:
        logger.info("Usage: python restore_mongodb.py <backup_filename>")
        logger.info("       python restore_mongodb.py list")
        return

    if sys.argv[1] == "list":
        restore.list_backups()
        return

    backup_filename = sys.argv[1]

    if restore.restore_backup(backup_filename):
        logger.info("Database restore completed successfully")
    else:
        logger.error("Database restore failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
