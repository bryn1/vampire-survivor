"""Game-number source inspection (placement-plan §5 pinned numbers, mirrored
in godot/scripts): WIN/BOSS thresholds, heal drop chance + clamp path, the
five ENEMY_TINTS, spawn gate minutes + rate cap, xp curve. These read the .gd
sources (the client is Godot WASM — no importable Python here), so the gate
is source-truth: constants must be exactly the plan values. MC 11026.
"""

import os
import re

import conftest

SCRIPTS = os.path.join(conftest.REPO, "godot", "scripts")


def read(name):
    with open(os.path.join(SCRIPTS, name), encoding="utf-8") as fh:
        return fh.read()


WORLD = read("world.gd")
GAME_STATE = read("game_state.gd")
MAIN = read("main.gd")
RENDER = read("render.gd")


def const(name, source):
    m = re.search(r"const\s+%s\s*:=\s*([-\d.]+)" % re.escape(name), source)
    assert m, "constant %s not found in source" % name
    return float(m.group(1))


# ---- thresholds -------------------------------------------------------------

def test_boss_at_540():
    assert const("BOSS_AT", WORLD) == 540.0


def test_win_threshold_600():
    # WIN lives in game_state.gd as WIN_TIME and is gated in main.gd; the plan
    # pins win at 600.0 s survival.
    assert const("WIN_TIME", GAME_STATE) == 600.0
    assert re.search(r"time\s*>=\s*GameState\.WIN_TIME", MAIN), \
        "main.gd must gate the win on the shared WIN_TIME constant"


def test_boss_gate_wired():
    assert re.search(r"time\s*>=\s*BOSS_AT", WORLD), "boss spawn must compare the clock to BOSS_AT"


# ---- heal drop ---------------------------------------------------------------

def test_heal_drop_chance():
    assert const("HEAL_DROP_CHANCE", WORLD) == 0.015


def test_heal_amount():
    assert const("HEAL_AMOUNT", WORLD) == 8.0


def test_heal_clamp_path_exists():
    # HP gain must be clamped at max_hp (plan: 'clamped to max_hp').
    assert "max_hp" in WORLD
    assert re.search(r"minf\(\s*game\.max_hp\s*,\s*game\.hp\s*\+\s*HEAL_AMOUNT\s*\)", WORLD), \
        "heal pickup path must clamp: minf(game.max_hp, game.hp + HEAL_AMOUNT)"


# ---- enemy gates + rate ------------------------------------------------------

def test_gates_minutes():
    # plan §5: gates 0/2/4/6 minutes for the four swarmers.
    m = re.search(r"GATES\s*:=\s*\[(.*)\]", WORLD)
    assert m, "GATES constant missing"
    pairs = re.findall(r"\[(\d+\.?\d*)\s*,\s*\"(\w+)\"\]", m.group(1))
    assert [(float(t), k) for t, k in pairs] == [
        (0.0, "wraith"), (2.0, "hound"), (4.0, "crawler"), (6.0, "cultist")]


def test_spawn_rate_capped_12():
    assert re.search(r"minf\(\s*12\.0\s*,\s*1\.0\s*\+\s*1\.3\s*\*\s*minute\s*\)", WORLD), \
        "spawn rate must be min(12, 1 + 1.3*minute) per plan §5"


def test_enemy_base_stats_per_plan():
    # wraith hp8 spd55 dmg2 xp1; hound 6/95/3/1; crawler 30/35/5/3; cultist 18/60/6/4; boss 3000/45/12.
    expected = {
        "wraith": (8.0, 55.0, 2.0, 1.0),
        "hound": (6.0, 95.0, 3.0, 1.0),
        "crawler": (30.0, 35.0, 5.0, 3.0),
        "cultist": (18.0, 60.0, 6.0, 4.0),
        "warden": (3000.0, 45.0, 12.0, 0.0),
    }
    block = WORLD[WORLD.index("const ENEMY_TYPES"):]
    for key, (hp, spd, dmg, xp) in expected.items():
        row = re.search(r"\"%s\":\s*\{\"hp\":\s*([\d.]+),\s*\"spd\":\s*([\d.]+),\s*\"dmg\":\s*([\d.]+),\s*\"xp\":\s*([\d.]+)" % key, block)
        assert row, "ENEMY_TYPES entry for %s missing/wrong shape" % key
        assert (float(row.group(1)), float(row.group(2)), float(row.group(3)), float(row.group(4))) == (hp, spd, dmg, xp)


# ---- xp curve -----------------------------------------------------------------

def test_xp_curve():
    # xpNext = 5 + 4L + L^2 (plan §5).
    assert re.search(r"return\s+5\s*\+\s*4\s*\*\s*level\s*\+\s*level\s*\*\s*level", GAME_STATE), \
        "xp_need must be 5 + 4*level + level*level"


# ---- ENEMY_TINTS ----------------------------------------------------------------

def test_five_enemy_tints_present():
    block = RENDER[RENDER.index("const ENEMY_TINTS"):]
    block = block[:block.index("\n\n") if "\n\n" in block else len(block)]
    keys = re.findall(r"\"(\w+)\"\s*:\s*Color\(", block)
    assert set(keys) == {"wraith", "hound", "crawler", "cultist", "warden"}, \
        "exactly the five swarm/boss tints must be defined, got %r" % keys
    assert len(keys) == 5
