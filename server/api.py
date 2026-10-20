"""Contract A: /api routes with validation, on top of the Database layer.

handle() answers every /api/* request and returns True once a response was
sent; static_app.py imports send_json from here so error bodies share one
shape. No exception text ever reaches a client (validation errors carry only
field reasons).
"""

import json

MAX_BODY_BYTES = 65536
NAME_MAX_LEN = 16

HEALTH_PATH = "/api/health"
HIGHSCORES_PATH = "/api/highscores"


def send_json(handler, status, payload):
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def send_error_json(handler, status, code, fields=None):
    error = {"code": code}
    if fields is not None:
        error["fields"] = fields
    send_json(handler, status, {"error": error})


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def validate_score(body):
    """Return {field: reason} for Contract A bounds; empty dict = valid."""
    fields = {}
    name = body.get("name")
    if not isinstance(name, str):
        fields["name"] = "name is required and must be a string"
    else:
        name = name.strip()
        if not name:
            fields["name"] = "name must not be empty"
        elif len(name) > NAME_MAX_LEN:
            fields["name"] = "name must be 1-16 characters"
        elif not name.isprintable():
            fields["name"] = "name must be printable characters"

    score = body.get("score")
    if not _is_int(score):
        fields["score"] = "score is required and must be an integer"
    elif not 0 <= score <= 999999999:
        fields["score"] = "score must be 0-999999999"

    survived = body.get("time_survived")
    if not _is_number(survived):
        fields["time_survived"] = "time_survived is required and must be a number"
    elif not 0 <= survived <= 3600:
        fields["time_survived"] = "time_survived must be 0-3600"

    kills = body.get("kills")
    if not _is_int(kills):
        fields["kills"] = "kills is required and must be an integer"
    elif not 0 <= kills <= 999999:
        fields["kills"] = "kills must be 0-999999"

    level = body.get("level")
    if not _is_int(level):
        fields["level"] = "level is required and must be an integer"
    elif not 1 <= level <= 999:
        fields["level"] = "level must be 1-999"

    return fields


def _read_json_body(handler):
    """Return (obj, None) or (None, True) after sending 400 BAD_JSON.

    A body that is valid JSON but not an object is a shape error, so it is
    reported as VALIDATION by the caller, not BAD_JSON.
    """
    try:
        length = int(handler.headers.get("Content-Length", "0"))
    except ValueError:
        send_error_json(handler, 400, "BAD_JSON")
        return None, True
    if length < 0 or length > MAX_BODY_BYTES:
        send_error_json(handler, 400, "BAD_JSON")
        return None, True
    try:
        obj = json.loads(handler.rfile.read(length).decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        send_error_json(handler, 400, "BAD_JSON")
        return None, True
    return obj, False


def handle(handler, method, path, db):
    """Answer /api/* per Contract A. Returns True if a response was sent."""
    if path == HEALTH_PATH:
        if method == "GET":
            send_json(handler, 200, {"status": "ok"})
        else:
            send_error_json(handler, 405, "METHOD_NOT_ALLOWED")
        return True
    if path == HIGHSCORES_PATH:
        if method == "GET":
            send_json(handler, 200, {"scores": db.top_scores()})
        elif method == "POST":
            _handle_post_score(handler, db)
        else:
            send_error_json(handler, 405, "METHOD_NOT_ALLOWED")
        return True
    if path.startswith("/api/"):
        send_error_json(handler, 404, "NOT_FOUND")
        return True
    return False


def _handle_post_score(handler, db):
    body, bad = _read_json_body(handler)
    if bad:
        return
    if not isinstance(body, dict):
        send_error_json(handler, 422, "VALIDATION",
                        {"body": "body must be a JSON object"})
        return
    fields = validate_score(body)
    if fields:
        send_error_json(handler, 422, "VALIDATION", fields)
        return
    rank = db.insert_score(
        body["name"].strip(),
        body["score"],
        float(body["time_survived"]),
        body["kills"],
        body["level"],
    )
    send_json(handler, 201, {"ok": True, "rank": rank})
