#!/usr/bin/env python3
"""Snapshot Beszel's latest system stats to a static JSON file for the
dashboard widget. Reads Beszel's SQLite DB directly (read-only) rather than
calling its API, so the dashboard needs no authentication to display stats.

Meant to run on a short interval via cron:
  * * * * * /usr/bin/python3 /path/to/cyberdyne/scripts/beszel-snapshot.py

Usage:
  ./scripts/beszel-snapshot.py [config_dir] [output_path]
  Defaults: config_dir=./config, output_path=./caddy/dashboard/stats.json
"""

import json
import sqlite3
import sys
from pathlib import Path

repo_root = Path(__file__).resolve().parent.parent
config_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else repo_root / "config"
output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else repo_root / "caddy" / "dashboard" / "stats.json"

db_path = config_dir / "beszel" / "data.db"


def main():
    if not db_path.exists():
        return

    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        cur = con.cursor()
        cur.execute("SELECT info, status, updated FROM systems ORDER BY updated DESC LIMIT 1")
        row = cur.fetchone()
    finally:
        con.close()

    if row is None:
        return

    info_raw, status, updated = row
    info = json.loads(info_raw) if info_raw else {}

    snapshot = {
        "status": status,
        "cpu": info.get("cpu"),
        "mem": info.get("mp"),
        "disk": info.get("dp"),
        "load": info.get("la"),
        "updated": updated,
    }

    output_path.write_text(json.dumps(snapshot))


if __name__ == "__main__":
    main()
