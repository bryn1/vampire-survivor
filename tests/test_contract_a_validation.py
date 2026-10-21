"""Contract A validation negatives, black-box over HTTP against the real
server (pinned contract, placement-plan §2): per-field type/negative/missing,
name boundaries 16-ok/17-reject/empty, unicode, huge score, bools/float-ints
rejected, BAD_JSON, non-object body. MC 11026.
"""

import json

import pytest

from conftest import get_json, http_request, post_json

BASE = {"name": "Tester", "score": 1000, "time_survived": 123.5, "kills": 42, "level": 3}
ALL_FIELDS = ["name", "score", "time_survived", "kills", "level"]


def body_without(field):
    body = dict(BASE)
    del body[field]
    return body


def body_with(**overrides):
    return dict(BASE, **overrides)


def expect_422(server, body, *fields):
    status, payload = post_json(server.port, "/api/highscores", body)
    assert status == 422, "expected 422 for %r, got %d" % (body, status)
    err = payload["error"]
    assert err["code"] == "VALIDATION"
    reported = set(err["fields"])
    for field in fields:
        assert field in reported, "%r not flagged in %r" % (field, reported)
    for field in ALL_FIELDS:
        if field not in fields and field != "body":
            assert field not in reported, "clean field %r wrongly flagged in %r" % (field, reported)
    return err


def expect_201(server, body):
    status, payload = post_json(server.port, "/api/highscores", body)
    assert status == 201, "expected 201 for %r, got %d %r" % (body, status, payload)
    assert payload["ok"] is True
    assert isinstance(payload["rank"], int)


# ---- name ----------------------------------------------------------------

@pytest.mark.parametrize("bad", ["", "   ", "a" * 17, "\x01abc", "ab\x7f", 123, None, ["x"], True])
def test_name_rejected(server, bad):
    expect_422(server, body_with(name=bad), "name")


def test_name_16_ok_17_rejected_boundary(server):
    expect_201(server, body_with(name="a" * 16))
    expect_422(server, body_with(name="a" * 17), "name")


def test_name_unicode_accepted(server):
    expect_201(server, body_with(name="Är Än Ö — ☀ 漢字"))


@pytest.mark.parametrize("bad", ["x" * 17, "y" * 300])
def test_name_long_rejects(server, bad):
    expect_422(server, body_with(name=bad), "name")


# ---- score ----------------------------------------------------------------

@pytest.mark.parametrize("bad", ["abc", "", None, 1.5, True, False, -1, -1000000,
                                 1000000000, 999999999 * 10, 10 ** 30])
def test_score_rejected(server, bad):
    expect_422(server, body_with(score=bad), "score")


@pytest.mark.parametrize("ok", [0, 1, 999999999])
def test_score_boundaries_ok(server, ok):
    expect_201(server, body_with(score=ok))


def test_huge_score_rejected_not_overflow(server):
    # JSON parses 10**40 fine in Python; the server must still 422, not 500.
    raw = dict(BASE, score=10 ** 40)
    status, _, data = http_request(server.port, "POST", "/api/highscores", body=raw)
    assert status == 422
    assert json.loads(data.decode("utf-8"))["error"]["code"] == "VALIDATION"


# ---- time_survived ---------------------------------------------------------

@pytest.mark.parametrize("bad", ["x", "", None, True, -0.5, -1, 3601, 99999.9])
def test_time_survived_rejected(server, bad):
    expect_422(server, body_with(time_survived=bad), "time_survived")


@pytest.mark.parametrize("ok", [0, 0.0, 3600, 3600.0, 12.5, 599.9])
def test_time_survived_boundaries_ok(server, ok):
    expect_201(server, body_with(time_survived=ok))


# ---- kills ----------------------------------------------------------------

@pytest.mark.parametrize("bad", [None, "1", 1.0, True, -1, 1000000, 999999999])
def test_kills_rejected(server, bad):
    expect_422(server, body_with(kills=bad), "kills")


@pytest.mark.parametrize("ok", [0, 1, 999999])
def test_kills_boundaries_ok(server, ok):
    expect_201(server, body_with(kills=ok))


# ---- level ----------------------------------------------------------------

@pytest.mark.parametrize("bad", [None, "1", 0, -1, 1000, 1.5, True])
def test_level_rejected(server, bad):
    expect_422(server, body_with(level=bad), "level")


@pytest.mark.parametrize("ok", [1, 2, 999])
def test_level_boundaries_ok(server, ok):
    expect_201(server, body_with(level=ok))


# ---- missing fields / whole body ---------------------------------------------

@pytest.mark.parametrize("missing", ALL_FIELDS)
def test_each_field_required(server, missing):
    expect_422(server, body_without(missing), missing)


def test_empty_object_flags_every_field(server):
    expect_422(server, {}, *ALL_FIELDS)


def test_multiple_bad_fields_all_reported(server):
    expect_422(server, {"name": "", "score": -5, "kills": "x", "level": 0,
                       "time_survived": None},
               "name", "score", "kills", "level", "time_survived")


@pytest.mark.parametrize("raw_body", ["[1,2]", '"str"', "42", "null"])
def test_valid_json_non_object_is_422(server, raw_body):
    status, _, data = http_request(server.port, "POST", "/api/highscores",
                                body=raw_body.encode("utf-8"))
    assert status == 422
    payload = json.loads(data.decode("utf-8"))
    assert payload["error"]["code"] == "VALIDATION"


@pytest.mark.parametrize("raw_body", [b"{oops", b"", b"\x00\x01", b"{'single': 'quotes'}"])
def test_malformed_json_is_400_bad_json(server, raw_body):
    status, _, data = http_request(server.port, "POST", "/api/highscores", body=raw_body)
    assert status == 400
    assert json.loads(data.decode("utf-8"))["error"]["code"] == "BAD_JSON"


def test_no_state_leak_from_rejected_posts(server):
    # Every rejection above must have written nothing: no name that was ONLY
    # ever sent in a rejected payload may appear in the live leaderboard.
    status, payload = post_json(server.port, "/api/highscores", BASE)
    assert status == 201
    _, listed = get_json(server.port, "/api/highscores")
    rejected_only_names = {"", "   ", "a" * 17, "x" * 17, "y" * 300,
                           "\x01abc", "ab\x7f", "1", "x"}
    seen = {row["name"] for row in listed["scores"]}
    assert not (seen & rejected_only_names), \
        "rejected payloads leaked into leaderboard: %r" % (seen & rejected_only_names)
