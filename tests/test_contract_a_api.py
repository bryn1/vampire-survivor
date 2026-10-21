"""Contract A positives: health, GET/POST /api/highscores, rank semantics,
tie ordering, top-10 cap, persistence across restart, 404/405. Black-box:
every assertion is made against the running server over HTTP (Contract A as
pinned in placement-plan §2). MC 11026.
"""

import json
import sqlite3

import pytest

import conftest
from conftest import get_json, http_request, post_json, RESTART_DB, RESTART_PORT, Server, purge_db

VALID = {"name": "Tester", "score": 1000, "time_survived": 123.5, "kills": 42, "level": 3}


def seed_rows(db_path, rows):
    """Insert rows with controlled created_at directly into the same db file the
    live server opened (SQLite serialises writers; the server's next read sees
    them). rows: list of (name, score, time_survived, kills, level, created_at)."""
    conn = sqlite3.connect(db_path, timeout=10)
    try:
        conn.executemany(
            "INSERT INTO highscores (name, score, time_survived, kills, level, created_at)"
            " VALUES (?, ?, ?, ?, ?, ?)", rows)
        conn.commit()
    finally:
        conn.close()


def test_health_ok(server):
    status, payload = get_json(server.port, "/api/health")
    assert status == 200
    assert payload == {"status": "ok"}


def test_highscores_empty_on_fresh_db(server):
    status, payload = get_json(server.port, "/api/highscores")
    assert status == 200
    assert payload == {"scores": []}


def test_post_valid_returns_201_and_rank(server):
    status, payload = post_json(server.port, "/api/highscores", VALID)
    assert status == 201
    assert payload == {"ok": True, "rank": 1}


def test_posted_row_readable_via_get(server):
    post_json(server.port, "/api/highscores", VALID)
    status, payload = get_json(server.port, "/api/highscores")
    assert status == 200
    assert len(payload["scores"]) == 1
    row = payload["scores"][0]
    assert set(row) == {"rank", "name", "score", "time_survived", "kills", "level", "created_at"}
    assert row["rank"] == 1
    assert row["name"] == VALID["name"]
    assert row["score"] == VALID["score"]
    assert row["time_survived"] == pytest.approx(VALID["time_survived"])
    assert row["kills"] == VALID["kills"]
    assert row["level"] == VALID["level"]
    assert isinstance(row["created_at"], str) and row["created_at"]


def test_name_is_trimmed_on_store(server):
    body = dict(VALID, name="  Padded  ")
    status, _ = post_json(server.port, "/api/highscores", body)
    assert status == 201
    _, payload = get_json(server.port, "/api/highscores")
    assert payload["scores"][0]["name"] == "Padded"


def test_rank_counts_strictly_higher_scores(server):
    post_json(server.port, "/api/highscores", dict(VALID, name="a", score=500))
    post_json(server.port, "/api/highscores", dict(VALID, name="b", score=700))
    status, payload = post_json(server.port, "/api/highscores", dict(VALID, name="c", score=600))
    assert status == 201 and payload["rank"] == 2
    # a lower score lands behind both; a higher one is rank 1
    _, payload = post_json(server.port, "/api/highscores", dict(VALID, name="d", score=100))
    assert payload["rank"] == 4
    _, payload = post_json(server.port, "/api/highscores", dict(VALID, name="e", score=999))
    assert payload["rank"] == 1


def test_tie_shares_rank_and_earlier_row_lists_first(server):
    # Controlled created_at so the tie order is deterministic, not clock luck.
    seed_rows(server.db_path, [
        ("first-100", 100, 10.0, 1, 1, "2026-01-01T00:00:01.000000+00:00"),
        ("second-100", 100, 11.0, 1, 1, "2026-01-01T00:00:02.000000+00:00"),
        ("top-250", 250, 12.0, 1, 1, "2026-01-01T00:00:03.000000+00:00"),
        ("low-50", 50, 13.0, 1, 1, "2026-01-01T00:00:04.000000+00:00"),
    ])
    status, payload = get_json(server.port, "/api/highscores")
    assert status == 200
    rows = payload["scores"]
    assert [(r["name"], r["rank"]) for r in rows] == [
        ("top-250", 1),      # strictly highest -> rank 1
        ("first-100", 2),    # tie: earlier created_at lists first, keeps rank 2
        ("second-100", 2),   # tied score shares rank 2 (1 + strictly-higher count)
        ("low-50", 4),       # 250 and both 100s are strictly higher -> rank 4
    ]
    # POSTing a third tied score must also report rank 2.
    status, payload = post_json(server.port, "/api/highscores",
                                dict(VALID, name="third-100", score=100))
    assert status == 201 and payload["rank"] == 2


def test_top10_cap_and_score_desc_order(server):
    seed_rows(server.db_path, [
        ("s%03d" % s, s, 1.0, 1, 1, "2026-01-01T00:%02d:%02d.000000+00:00" % (s // 60, s % 60))
        for s in range(1, 13)  # scores 1..12 -> 12 rows
    ])
    _, payload = get_json(server.port, "/api/highscores")
    rows = payload["scores"]
    assert len(rows) == 10
    scores = [r["score"] for r in rows]
    assert scores == sorted(scores, reverse=True)
    assert scores == list(range(12, 2, -1))  # top-10 of 1..12
    assert rows[0]["rank"] == 1


def test_persistence_across_server_restart():
    # Second sequential instance: its own port 8932 + own /tmp db (8931 is held
    # by the module fixture; the repo data/ dir and 8123 stay untouched).
    purge_db(RESTART_DB)
    first = Server(RESTART_PORT, RESTART_DB)
    try:
        status, _ = post_json(first.port, "/api/highscores", dict(VALID, name="persist", score=4242))
        assert status == 201
    finally:
        first.stop()
    assert first.proc.poll() is not None  # exact PID reaped before restart
    second = Server(RESTART_PORT, RESTART_DB, purge=False)  # keep the db: that's the test
    try:
        status, payload = get_json(second.port, "/api/highscores")
        assert status == 200
        names = [r["name"] for r in payload["scores"]]
        assert "persist" in names
        row = payload["scores"][0]
        assert row["score"] == 4242 and row["rank"] == 1
    finally:
        second.stop()


@pytest.mark.parametrize("method", ["GET", "POST", "PUT", "DELETE", "PATCH"])
def test_unknown_api_path_is_404_not_found(server, method):
    status, _, data = http_request(server.port, method, "/api/nonexistent")
    assert status == 404
    payload = json.loads(data.decode("utf-8"))
    assert payload["error"]["code"] == "NOT_FOUND"


@pytest.mark.parametrize("method", ["POST", "PUT", "DELETE", "PATCH"])
def test_wrong_method_on_health_is_405(server, method):
    status, _, data = http_request(server.port, method, "/api/health")
    assert status == 405
    assert json.loads(data.decode("utf-8"))["error"]["code"] == "METHOD_NOT_ALLOWED"


@pytest.mark.parametrize("method", ["PUT", "DELETE", "PATCH"])
def test_wrong_method_on_highscores_is_405(server, method):
    status, _, data = http_request(server.port, method, "/api/highscores")
    assert status == 405
    assert json.loads(data.decode("utf-8"))["error"]["code"] == "METHOD_NOT_ALLOWED"
