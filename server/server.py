"""Hollow Dawn server entrypoint: static files + highscores API, one port.

Run: python3 server/server.py
Env: VS_PORT (default 8123), VS_DB (default <repo-root>/data/highscores.db).
Binds 127.0.0.1 per Contract A. This file only wires: routing decisions live
in api.py, static serving in static_app.py, storage in db.py.
"""

import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit

import api
import static_app
from db import Database

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATIC_DIR = os.path.join(REPO_ROOT, "static")
DEFAULT_DB_PATH = os.path.join(REPO_ROOT, "data", "highscores.db")
HOST = "127.0.0.1"
DEFAULT_PORT = 8123


class GameHandler(BaseHTTPRequestHandler):
    server_version = "HollowDawn/1.0"
    db = None  # set by main() before serving

    def _dispatch(self, method):
        path = unquote(urlsplit(self.path).path)
        if not api.handle(self, method, path, self.db):
            static_app.serve(self, STATIC_DIR)

    def do_GET(self):
        self._dispatch("GET")

    def do_POST(self):
        self._dispatch("POST")

    def do_PUT(self):
        self._dispatch("PUT")

    def do_DELETE(self):
        self._dispatch("DELETE")

    def do_PATCH(self):
        self._dispatch("PATCH")


def main():
    port = int(os.environ.get("VS_PORT", str(DEFAULT_PORT)))
    db_path = os.environ.get("VS_DB", DEFAULT_DB_PATH)
    GameHandler.db = Database(db_path)
    httpd = ThreadingHTTPServer((HOST, port), GameHandler)
    print("Hollow Dawn server on http://%s:%d (db: %s)"
          % (HOST, port, db_path), flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()
        GameHandler.db.close()


if __name__ == "__main__":
    main()
