"""Shared fixtures: the REAL server as a subprocess on seat-owned ports.

MC 11026 test pass (run 202610201514-81bb9a6c). Port 8931 is this run's main
instance, 8932 only for the restart test's second sequential instance. Port
8123 and the repo's data/ dir are NEVER touched: every VS_DB lives in /tmp.
"""

import http.client
import json
import os
import sqlite3
import subprocess
import sys
import time

import pytest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVER_MAIN = os.path.join(REPO, "server", "server.py")
STATIC_DIR = os.path.join(REPO, "static")

MAIN_PORT = 8931
MAIN_DB = "/tmp/yourown.db"
RESTART_PORT = 8932
RESTART_DB = "/tmp/yourown-restart.db"

MAIN_SERVER = None  # set by the module fixture; tracked so the session can sweep


def purge_db(path):
    for suffix in ("", "-journal", "-wal", "-shm"):
        try:
            os.remove(path + suffix)
        except FileNotFoundError:
            pass


def http_request(port, method, path, body=None, timeout=20):
    """One-shot request. body: dict|list -> JSON, bytes -> raw, None -> no body.

    Returns (status, content_type, raw_bytes).
    """
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=timeout)
    headers = {}
    payload = None
    if body is not None:
        payload = body if isinstance(body, bytes) else json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    try:
        conn.request(method, path, body=payload, headers=headers)
        resp = conn.getresponse()
        data = resp.read()
        return resp.status, resp.getheader("Content-Type"), data
    finally:
        conn.close()


def get_json(port, path, **kw):
    status, _, data = http_request(port, "GET", path, **kw)
    return status, json.loads(data.decode("utf-8"))


def post_json(port, path, body, **kw):
    status, _, data = http_request(port, "POST", path, body=body, **kw)
    return status, json.loads(data.decode("utf-8"))


class Server:
    """Spawn server/server.py on an exact port + db; stop kills that exact PID."""

    def __init__(self, port, db_path, purge=True):
        self.port = port
        self.db_path = db_path
        if purge:
            purge_db(db_path)
        env = dict(os.environ, VS_PORT=str(port), VS_DB=db_path)
        self.proc = subprocess.Popen(
            [sys.executable, SERVER_MAIN], cwd=REPO, env=env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        deadline = time.monotonic() + 15.0
        last_err = None
        while time.monotonic() < deadline:
            try:
                status, _, data = http_request(port, "GET", "/api/health", timeout=2)
                if status == 200:
                    return
                last_err = "health returned %d" % status
            except (ConnectionRefusedError, OSError, http.client.HTTPException) as exc:
                last_err = repr(exc)
            if self.proc.poll() is not None:
                out, err = self.proc.communicate()
                raise RuntimeError(
                    "server died at startup (rc=%s): %s %s" % (self.proc.returncode, out, err))
            time.sleep(0.05)
        self.stop()
        raise RuntimeError("server on port %d never became healthy: %s" % (port, last_err))

    def stop(self):
        """Terminate the exact PID we spawned; escalate to kill, then reap."""
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(timeout=5)


@pytest.fixture(scope="module")
def server():
    """Fresh REAL server per test module on port 8931 with a fresh /tmp db."""
    global MAIN_SERVER
    srv = Server(MAIN_PORT, MAIN_DB)
    MAIN_SERVER = srv
    try:
        yield srv
    finally:
        srv.stop()
        MAIN_SERVER = None


@pytest.fixture(autouse=True)
def clean_leaderboard(request):
    """Empty the leaderboard before each test so per-test expectations are
    deterministic on the shared module server (direct DELETE on OUR /tmp db).
    Only engages for tests that actually use the server fixture."""
    if "server" not in request.fixturenames:
        yield
        return
    srv = request.getfixturevalue("server")
    conn = sqlite3.connect(srv.db_path, timeout=10)
    try:
        conn.execute("DELETE FROM highscores")
        conn.commit()
    finally:
        conn.close()
    yield
