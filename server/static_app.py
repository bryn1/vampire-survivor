"""Static file serving for the game client, docroot = <repo-root>/static.

Every path is resolved with realpath and required to stay inside the docroot
via commonpath; anything escaping or with a non-allowlisted extension is a
404 (never 403), matching the /api 404 shape through api.send_error_json.
"""

import os
from urllib.parse import unquote, urlsplit

from api import send_error_json

CONTENT_TYPES = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".png": "image/png",
}


def _resolve(docroot, raw_path):
    """Absolute path inside realpath(docroot), or None if it escapes."""
    request_path = unquote(urlsplit(raw_path).path)
    if request_path == "/":
        request_path = "/index.html"
    real_root = os.path.realpath(docroot)
    candidate = os.path.realpath(
        os.path.join(real_root, request_path.lstrip("/")))
    if os.path.commonpath([candidate, real_root]) != real_root:
        return None
    return candidate


def serve(handler, docroot):
    """Serve handler.path statically; always sends exactly one response."""
    path = _resolve(docroot, handler.path)
    if path is None or not os.path.isfile(path):
        send_error_json(handler, 404, "NOT_FOUND")
        return
    extension = os.path.splitext(path)[1].lower()
    content_type = CONTENT_TYPES.get(extension)
    if content_type is None:
        send_error_json(handler, 404, "NOT_FOUND")
        return
    try:
        with open(path, "rb") as handle:
            body = handle.read()
    except OSError:
        send_error_json(handler, 404, "NOT_FOUND")
        return
    handler.send_response(200)
    handler.send_header("Content-Type", content_type)
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)
