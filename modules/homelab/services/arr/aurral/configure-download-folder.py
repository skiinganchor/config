"""Enforce the declared download folder while Aurral is stopped."""

import os
from pathlib import Path
import sqlite3
import time


data_dir = Path(os.environ["AURRAL_DATA_DIR"])
database = Path(os.environ.get("AURRAL_DB_PATH", str(data_dir / "aurral.db")))
download_dir = os.environ["DOWNLOAD_FOLDER"]

# A new installation uses DOWNLOAD_FOLDER until Aurral creates its database.
if database.exists():
    with sqlite3.connect(f"{database.as_uri()}?mode=rw", uri=True) as connection:
        connection.execute("PRAGMA busy_timeout = 5000")
        has_settings = connection.execute(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'settings'"
        ).fetchone()
        if has_settings:
            saved = connection.execute(
                "SELECT value FROM settings WHERE key = 'downloadFolderPath'"
            ).fetchone()
            if saved is None or saved[0] != download_dir:
                backups = data_dir / "backups"
                backups.mkdir(mode=0o700, exist_ok=True)
                backup = backups / f"before-download-folder-{time.time_ns()}.db"
                with sqlite3.connect(backup) as snapshot:
                    connection.backup(snapshot)
                backup.chmod(0o600)
                connection.execute(
                    "INSERT INTO settings (key, value) VALUES ('downloadFolderPath', ?) "
                    "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                    (download_dir,),
                )
                print(f"Aurral download folder set to {download_dir}; backup: {backup}")
                if saved and saved[0]:
                    print(f"Existing files and job paths remain at {saved[0]}.")
