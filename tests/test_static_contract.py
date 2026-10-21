"""Contract A static-serving surface, black-box over HTTP: GET / serves
static/, content-type map (.png/.wasm/.pck/.html), path traversal refused
(404 never 403/500), HEAD -> 501 (documented limitation: handler defines
only GET/POST/PUT/DELETE/PATCH). MC 11026.
"""

import json
import os

import conftest
from conftest import http_request, STATIC_DIR
from conftest import MAIN_PORT  # noqa: F401  (documents which port this file rides on)


def test_get_root_serves_static_index(server):
    status, ctype, data = http_request(server.port, "GET", "/")
    assert status == 200
    assert ctype and ctype.startswith("text/html")
    # The body must be the actual file on disk, not a stub.
    with open(os.path.join(STATIC_DIR, "index.html"), "rb") as fh:
        assert data == fh.read()


def test_get_named_static_html_matches_disk(server):
    status, ctype, data = http_request(server.port, "GET", "/index.html")
    assert status == 200 and ctype.startswith("text/html")
    assert b"<" in data  # looks like markup


def test_png_served_with_image_content_type(server):
    status, ctype, data = http_request(server.port, "GET", "/assets/player.png")
    assert status == 200
    assert ctype == "image/png"
    assert data.startswith(b"\x89PNG\r\n\x1a\n")


def test_wasm_content_type(server):
    status, ctype, data = http_request(server.port, "GET", "/index.wasm")
    assert status == 200
    assert ctype == "application/wasm"
    assert data.startswith(b"\x00asm")  # real WebAssembly module magic


def test_pck_content_type(server):
    status, ctype, data = http_request(server.port, "GET", "/index.pck")
    assert status == 200
    assert ctype == "application/octet-stream"
    assert len(data) == os.path.getsize(os.path.join(STATIC_DIR, "index.pck"))


def test_js_served(server):
    status, ctype, _ = http_request(server.port, "GET", "/index.js")
    assert status == 200
    assert ctype == "text/javascript; charset=utf-8"


def test_missing_static_file_is_404_json_not_403(server):
    status, _, data = http_request(server.port, "GET", "/definitely-not-here.nope")
    assert status == 404
    assert json.loads(data.decode("utf-8"))["error"]["code"] == "NOT_FOUND"


def test_disallowed_extension_under_docroot_is_404(server):
    # index.pck exists; same file requested with a disallowed extension must 404.
    status, _, data = http_request(server.port, "GET", "/index.pck.txt")
    assert status == 404
    assert json.loads(data.decode("utf-8"))["error"]["code"] == "NOT_FOUND"


def test_dotfiles_not_served(server):
    # static/../.gitignore would be .gitignore at repo root if traversal worked.
    status, _, data = http_request(server.port, "GET", "/../.gitignore")
    assert status == 404
    assert json.loads(data.decode("utf-8"))["error"]["code"] == "NOT_FOUND"


def test_path_traversal_refused(server):
    cases = [
        "/../server/server.py",
        "/%2e%2e/server/server.py",
        "/..%2fserver%2fserver.py",
        "/assets/../../server/db.py",
        "/assets/%2e%2e/%2e%2e/server/db.py",
        "/static/server.py",
        "/.git/config",
        "/%2e%2e%2f%2e%2e%2fetc/passwd",
    ]
    for path in cases:
        status, _, data = http_request(server.port, "GET", path)
        assert status == 404, "%s -> %d (expected 404)" % (path, status)
        body = data.decode("utf-8")
        assert b"sqlite3" not in data and b"root:" not in data, \
            "%s leaked file contents: %s" % (path, body[:200])
        try:
            assert json.loads(body)["error"]["code"] == "NOT_FOUND"
        except (ValueError, KeyError):
            raise AssertionError("%s returned non-Contract 404 body: %s" % (path, body[:200]))


def test_absolute_traversal_with_encoded_slash_deep(server):
    status, _, _ = http_request(server.port, "GET", "/..%2f..%2f..%2fetc%2fpasswd")
    assert status == 404


def test_head_returns_501_documented(server):
    # Documented limitation (verdict README): no do_HEAD -> BaseHTTPRequestHandler
    # answers 501. This test pins the documented behaviour, red if it changes.
    status, _, data = http_request(server.port, "HEAD", "/")
    assert status == 501


def test_traversal_never_500s_batch(server):
    # Negative fuzz: nasty paths must answer 404 JSON, never crash the route.
    nasty = ["/" + "a/" * 200, "//..", "/./../x", "/index.html/../x",
             "/%c0%ae%c0%ae/etc/passwd"]
    for path in nasty:
        status, _, _ = http_request(server.port, "GET", path)
        assert status in (200, 404), "%s -> %d (expected 404 or a legit 200)" % (path, status)


def test_nul_byte_path_gets_one_404_response_not_a_dropped_connection(server):
    # FINDING (MC 11026, P2): paths containing an encoded NUL crash the
    # handler thread — os.path.realpath raises ValueError: embedded null
    # byte (static_app.py _resolve) — so the request dies with no response
    # (connection closed) instead of the contract's one-404-per-request.
    # Blast radius is probed too: the server PROCESS must survive NUL traffic.
    import http.client
    dropped = None
    for path in ("/%00", "/assets/%00.png", "/%00../server/server.py"):
        conn = http.client.HTTPConnection("127.0.0.1", server.port, timeout=5)
        try:
            conn.request("GET", path)
            resp = conn.getresponse()
            resp.read()
            if resp.status != 404:
                dropped = "%s answered %d, expected 404" % (path, resp.status)
                break
        except http.client.RemoteDisconnected:
            dropped = "%r was answered with a DROPPED CONNECTION, not one 404 " \
                      "JSON response" % path
            break
        finally:
            conn.close()
    status, _, _ = http_request(server.port, "GET", "/api/health")
    assert status == 200, "server process died on NUL path — worse than a dropped request"
    assert dropped is None, (
        "handler thread ValueError: embedded null byte — %s (static_app.py "
        "_resolve does not guard realpath against NUL)" % dropped)
