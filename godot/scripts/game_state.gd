# Run state + phase machine + the Contract B snapshot (exact 12 fields).
class_name GameState
extends RefCounted

const BASE_SPEED := 140.0
const IFRAMES := 0.5
const WIN_TIME := 600.0
const MAX_HP := 100.0

var phase := "menu" # menu | playing | levelup | gameover | win
var paused := false # Esc freeze; not a phase value (Contract B)
var muted := false # internal no-op flag: this build ships no audio
var time := 0.0 # seconds, advances only while playing and not paused
var run_id := ""
var hp := MAX_HP
var max_hp := MAX_HP
var level := 1
var xp := 0.0
var gold := 0
var kills := 0
var pending_levels := 0
var weapons: Array = [] # [{id, level, cd}] — ids per plan §5
var passives := {"ferocity": 0, "haste": 0, "ward": 0, "grip": 0, "insight": 0}
var player := {"x": 0.0, "y": 0.0, "dir_x": 1.0, "dir_y": 0.0, "iframes": 0.0}
var stats: Dictionary = {}


static func xp_need(level: int) -> int:
	return 5 + 4 * level + level * level


func player_speed() -> float:
	return BASE_SPEED * (1.0 + 0.08 * passives.haste)


func damage_taken(raw: float) -> float:
	return maxf(0.0, raw - passives.ward)


func damage_multiplier() -> float:
	return 1.0 + 0.1 * passives.ferocity


func start_run() -> void:
	phase = "playing"
	paused = false
	time = 0.0
	run_id = "rd-" + _random_hex(8)
	hp = MAX_HP
	max_hp = MAX_HP
	level = 1
	xp = 0.0
	gold = 0
	kills = 0
	pending_levels = 0
	weapons = [{"id": "talon", "level": 1, "cd": 0.0}]
	passives = {"ferocity": 0, "haste": 0, "ward": 0, "grip": 0, "insight": 0}
	player = {"x": 0.0, "y": 0.0, "dir_x": 1.0, "dir_y": 0.0, "iframes": 0.0}
	stats = {}


func set_phase(next_phase: String) -> void:
	phase = next_phase
	paused = false


func end_run(result: String) -> void:
	stats = {
		"time": time,
		"kills": kills,
		"level": level,
		"gold": gold,
	}
	phase = result # "gameover" | "win"


# Insight multiplies gained xp; overflow may raise several levels at once.
func add_xp(amount: float) -> void:
	xp += amount * (1.0 + 0.15 * passives.insight)
	while xp >= float(xp_need(level)):
		xp -= float(xp_need(level))
		level += 1
		pending_levels += 1


# Exact Contract B shape, field for field, serialized for window.__vsSnapshot.
func snapshot_json(enemy_count: int) -> String:
	var weapon_rows: Array = []
	for w in weapons:
		weapon_rows.append({"id": w.id, "level": w.level})
	return JSON.stringify({
		"phase": phase,
		"hp": hp,
		"maxHp": max_hp,
		"level": level,
		"xp": xp,
		"xpNext": xp_need(level),
		"gold": gold,
		"kills": kills,
		"time": time,
		"enemies": enemy_count,
		"weapons": weapon_rows,
		"runId": run_id,
	})


func _random_hex(byte_count: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := ""
	for i in byte_count:
		out += "%02x" % (rng.randi() % 256)
	return out
