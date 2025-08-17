#!/usr/bin/env python3
"""
MongoDB Backup Script for AutoSpot
Creates compressed backups of the MongoDB database with timestamps.
"""

import os
import sys
import subprocess
import datetime
import logging
import shutil
from pathlib import Path

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.FileHandler("/app/logs/backup.log"), logging.StreamHandler()],
)
logger = logging.getLogger(__name__)


class MongoBackup:
    def __init__(self):
        self.mongodb_uri = os.getenv("MONGODB_URI", "mongodb://mongo:27017")
        self.database_name = os.getenv("DATABASE_NAME", "parking_app")
        self.backup_dir = Path("/app/backups")
        self.backup_dir.mkdir(parents=True, exist_ok=True)

        # Create logs directory
        logs_dir = Path("/app/logs")
        logs_dir.mkdir(parents=True, exist_ok=True)

    def create_backup(self):
        """Create a timestamped backup of the MongoDB database."""
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_filename = f"autospot_backup_{timestamp}"
        backup_path = self.backup_dir / backup_filename
        compressed_path = self.backup_dir / f"{backup_filename}.tar.gz"

        logger.info(f"Starting backup: {backup_filename}")

        try:
            # Create mongodump command
            cmd = [
                "mongodump",
                "--uri",
                self.mongodb_uri,
                "--db",
                self.database_name,
                "--out",
                str(backup_path),
            ]

            # Execute mongodump
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode != 0:
                logger.error(f"Mongodump failed: {result.stderr}")
                return False

            # Check if backup directory was created and has content
            db_backup_path = backup_path / self.database_name
            if not db_backup_path.exists():
                logger.warning(f"Database backup directory not found: {db_backup_path}")
                logger.info("Creating empty backup for empty database")
                backup_path.mkdir(parents=True, exist_ok=True)
                db_backup_path.mkdir(parents=True, exist_ok=True)
                # Create a metadata file to indicate this is an empty backup
                (db_backup_path / "empty_backup.txt").write_text(
                    f"Empty backup created at {timestamp}"
                )

            # Compress the backup
            shutil.make_archive(str(backup_path), "gztar", str(backup_path))

            # Remove uncompressed directory
            shutil.rmtree(backup_path)

            # Get file size
            file_size = compressed_path.stat().st_size
            file_size_mb = file_size / (1024 * 1024)

            logger.info(
                f"Backup completed successfully: {compressed_path.name} ({file_size_mb:.2f} MB)"
            )

            return True

        except Exception as e:
            logger.error(f"Backup failed: {str(e)}")
            return False

    def cleanup_old_backups(self, days_to_keep=7):
        """Remove backup files older than specified days."""
        logger.info(f"Cleaning up backups older than {days_to_keep} days")

        cutoff_date = datetime.datetime.now() - datetime.timedelta(days=days_to_keep)
        removed_count = 0

        for backup_file in self.backup_dir.glob("autospot_backup_*.tar.gz"):
            file_time = datetime.datetime.fromtimestamp(backup_file.stat().st_mtime)

            if file_time < cutoff_date:
                try:
                    backup_file.unlink()
                    logger.info(f"Removed old backup: {backup_file.name}")
                    removed_count += 1
                except Exception as e:
                    logger.error(f"Failed to remove {backup_file.name}: {str(e)}")

        logger.info(f"Cleanup completed. Removed {removed_count} old backups.")

    def list_backups(self):
        """List all available backups."""
        backups = list(self.backup_dir.glob("autospot_backup_*.tar.gz"))
        backups.sort(key=lambda x: x.stat().st_mtime, reverse=True)

        if not backups:
            logger.info("No backups found.")
            return

        logger.info("Available backups:")
        for backup in backups:
            file_time = datetime.datetime.fromtimestamp(backup.stat().st_mtime)
            file_size = backup.stat().st_size / (1024 * 1024)
            logger.info(
                f"  {backup.name} - {file_time.strftime('%Y-%m-%d %H:%M:%S')} ({file_size:.2f} MB)"
            )


def main():
    backup = MongoBackup()

    if len(sys.argv) > 1:
        if sys.argv[1] == "list":
            backup.list_backups()
            return
        elif sys.argv[1] == "cleanup":
            days = int(sys.argv[2]) if len(sys.argv) > 2 else 7
            backup.cleanup_old_backups(days)
            return

    # Default: create backup and cleanup
    if backup.create_backup():
        backup.cleanup_old_backups()
        logger.info("Backup process completed successfully")
    else:
        logger.error("Backup process failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
