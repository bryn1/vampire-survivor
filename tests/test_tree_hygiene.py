"""Tree hygiene gates for the deliverable repo (owner file-hygiene ruling +
plan §6 constraints): source size cap, zero marker words in server/ and
godot/scripts/, .gitignore coverage, and no db/data tracked in git. MC 11026.
"""

import os
import re
import subprocess

import conftest

REPO = conftest.REPO

# Marker words built by CONCATENATION so this test file can never match itself.
MARKER_RE = re.compile("(" + "TO" + "DO" + "|" + "FIX" + "ME)", re.IGNORECASE)

MAX_SOURCE_LINES = 300  # plan §6: every source file <= 300 lines


def walk_files(root, exts=None, skip_dirs=()):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        for fn in sorted(filenames):
            if exts is None or fn.endswith(exts):
                yield os.path.join(dirpath, fn)


def line_count(path):
    with open(path, "rb") as fh:
        data = fh.read()
    if not data:
        return 0
    n = data.count(b"\n")
    if not data.endswith(b"\n"):
        n += 1
    return n


def test_server_python_sources_within_line_cap():
    offenders = {}
    for path in walk_files(os.path.join(REPO, "server"), exts=(".py",), skip_dirs={"__pycache__"}):
        n = line_count(path)
        if n > MAX_SOURCE_LINES:
            offenders[os.path.relpath(path, REPO)] = n
    assert not offenders, "server/ .py files over %d lines: %r" % (MAX_SOURCE_LINES, offenders)


def test_godot_script_sources_within_line_cap():
    offenders = {}
    for path in walk_files(os.path.join(REPO, "godot", "scripts")):
        n = line_count(path)
        if n > MAX_SOURCE_LINES:
            offenders[os.path.relpath(path, REPO)] = n
    assert not offenders, "godot/scripts files over %d lines: %r" % (MAX_SOURCE_LINES, offenders)


def test_no_marker_words_in_server_or_scripts():
    hits = []
    for root in ("server", os.path.join("godot", "scripts")):
        for path in walk_files(os.path.join(REPO, root), skip_dirs={"__pycache__"}):
            with open(path, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
            for m in MARKER_RE.finditer(text):
                line = text.count("\n", 0, m.start()) + 1
                hits.append("%s:%d %s" % (os.path.relpath(path, REPO), line, m.group(0)))
    assert not hits, "marker words found (plan §6 zero-marker rule): %r" % hits


def test_gitignore_covers_data_and_tmp():
    with open(os.path.join(REPO, ".gitignore"), encoding="utf-8") as fh:
        lines = [ln.strip() for ln in fh if ln.strip() and not ln.startswith("#")]
    assert "data/" in lines or "data" in lines, ".gitignore must cover data/ (%r)" % lines
    assert ".tmp/" in lines or ".tmp" in lines, ".gitignore must cover .tmp/ (%r)" % lines


def _tracked_files():
    proc = subprocess.run(
        ["git", "-C", REPO, "ls-files"], capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, "git ls-files failed: %s" % proc.stderr
    return proc.stdout.splitlines()


def test_no_data_dir_or_db_files_tracked():
    tracked = _tracked_files()
    bad = [p for p in tracked if p.startswith("data/") or p.endswith(".db")
           or p.endswith(".db-wal") or p.endswith(".db-shm")]
    assert not bad, "git tracks runtime data (must be ignored): %r" % bad


def test_server_and_scripts_actually_tracked():
    # Guard for the guard: if the hygiene scans above were scanning nothing,
    # the files would not be tracked. Negative control — the tests above must
    # exercise real files, not an empty tree.
    tracked = _tracked_files()
    assert any(p.startswith("server/") and p.endswith(".py") for p in tracked), \
        "server/ .py files are not tracked in git — size/marker scans exercise nothing"
    assert any(p.startswith("godot/scripts/") and p.endswith(".gd") for p in tracked), \
        "godot/scripts/ .gd files are not tracked in git"


def test_tmp_not_tracked_and_runtime_db_absent_from_index():
    tracked = _tracked_files()
    assert not [p for p in tracked if p.startswith(".tmp/")], ".tmp/ must not be tracked"
