"""SQLite storage for Hollow Dawn highscores.

One shared connection guarded by a lock: ThreadingHTTPServer runs each request
in its own thread, so every statement goes through the lock (single-writer
discipline). Contract A schema, ranking formula and top-10 ordering live here.
"""

import os
import sqlite3
import threading
from datetime import datetime, timezone

SCORE_MAX = 999999999
KILLS_MAX = 999999
LEVEL_MAX = 999
TIME_MAX = 3600.0
TOP_N = 10

_SCHEMA = """
CREATE TABLE IF NOT EXISTS highscores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    score INTEGER,
    time_survived REAL,
    kills INTEGER,
    level INTEGER,
    created_at TEXT
)
"""

# Rank per Contract A: 1 + COUNT(rows with a strictly higher score), so tied
# scores share a rank. Ordering: score DESC, earlier created_at breaks ties.
_TOP_QUERY = (
    "SELECT (SELECT COUNT(*) + 1 FROM highscores h2"
    "          WHERE h2.score > h1.score) AS rank,"
    "       h1.name, h1.score, h1.time_survived, h1.kills, h1.level,"
    "       h1.created_at"
    "  FROM highscores h1"
    " ORDER BY h1.score DESC, h1.created_at ASC"
    " LIMIT ?"
)


def utc_now_text():
    """Fixed-width UTC timestamp; text order equals chronological order."""
    return datetime.now(timezone.utc).isoformat(timespec="microseconds")


class Database:
    def __init__(self, path):
        parent = os.path.dirname(os.path.abspath(path))
        os.makedirs(parent, exist_ok=True)
        self._lock = threading.Lock()
        self._conn = sqlite3.connect(path, check_same_thread=False)
        with self._lock:
            self._conn.execute(_SCHEMA)
            self._conn.commit()

    def insert_score(self, name, score, time_survived, kills, level):
        """Insert one run row and return its rank (1 + rows scoring higher)."""
        created_at = utc_now_text()
        with self._lock:
            self._conn.execute(
                "INSERT INTO highscores"
                " (name, score, time_survived, kills, level, created_at)"
                " VALUES (?, ?, ?, ?, ?, ?)",
                (name, score, time_survived, kills, level, created_at),
            )
            self._conn.commit()
            cursor = self._conn.execute(
                "SELECT COUNT(*) + 1 FROM highscores WHERE score > ?",
                (score,),
            )
            rank = cursor.fetchone()[0]
        return rank

    def top_scores(self, limit=TOP_N):
        """Top rows, score DESC with earlier created_at breaking ties, ranked."""
        with self._lock:
            cursor = self._conn.execute(_TOP_QUERY, (limit,))
            rows = cursor.fetchall()
        return [
            {
                "rank": rank,
                "name": name,
                "score": score,
                "time_survived": time_survived,
                "kills": kills,
                "level": level,
                "created_at": created_at,
            }
            for (rank, name, score, time_survived, kills, level,
                 created_at) in rows
        ]

    def close(self):
        with self._lock:
            self._conn.close()
