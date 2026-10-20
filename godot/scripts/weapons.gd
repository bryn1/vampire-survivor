# The six auto-fire weapons (plan §5): talon, ember, cleaver, halo, ward,
# spike. All fire without player input; level scales damage/count/rate.
class_name WeaponSystem
extends RefCounted

const IDS := ["talon", "ember", "cleaver", "halo", "ward", "spike"]
const MAX_LEVEL := 8

const META := {
	"talon": {"name": "Talon Lash", "icon": "icon-talon", "desc": "Raking arc in front of you"},
	"ember": {"name": "Ember Bolt", "icon": "icon-ember", "desc": "Bolts seek the nearest foe"},
	"cleaver": {"name": "Bone Cleaver", "icon": "icon-cleaver", "desc": "Heavy arcing throws"},
	"halo": {"name": "Cinder Halo", "icon": "icon-halo", "desc": "Cinders orbit around you"},
	"ward": {"name": "Warding Aura", "icon": "icon-ward", "desc": "Sears all who come close"},
	"spike": {"name": "Grave Spike", "icon": "icon-spike", "desc": "Bursts under the densest cluster"},
}

const BOLT_SPEED := 300.0
const THROW_SPEED := 260.0

# Transient state read by the renderer each frame.
var bolts: Array = []
var throws: Array = []
var bursts: Array = []
var arcs: Array = []
var rings: Array = []
var halos: Array = []

var _world: GameWorld
var _game: GameState # late-bound by main at boot


func bind(world: GameWorld, game: GameState) -> void:
	_world = world
	_game = game


func clear_fx() -> void:
	bolts.clear()
	throws.clear()
	bursts.clear()
	arcs.clear()
	rings.clear()
	halos.clear()


static func rate(level: int, base: float) -> float:
	return base * pow(0.96, level - 1)


func update(dt: float, game: GameState) -> void:
	for w in game.weapons:
		if w.id == "halo":
			_update_halo(w, dt, game)
			continue
		w.cd -= dt
		if w.cd > 0.0:
			continue
		_fire(w, game)
	_step_projectiles(dt)
	_step_fx(dt)


func _nearest(game: GameState, count: int) -> Array:
	var p: Dictionary = game.player
	var sorted := _world.enemies.duplicate()
	sorted.sort_custom(func(a, b): return _dist2(a, p) < _dist2(b, p))
	return sorted.slice(0, count)


static func _dist2(a: Dictionary, b: Dictionary) -> float:
	var dx: float = a.x - b.x
	var dy: float = a.y - b.y
	return dx * dx + dy * dy


# Every weapon routes damage through this single entry (ported from main.js).
func _hit(area: Dictionary, dmg: float, ticked := false) -> int:
	var n := 0
	var alive: Array = _world.enemies.duplicate()
	for e in alive:
		var er: float = 55.0 if e.boss else 17.0
		var dx: float = e.x - area.x
		var dy: float = e.y - area.y
		var reach: float = area.r + er
		if dx * dx + dy * dy > reach * reach:
			continue
		if area.has("half"):
			var da: float = atan2(dy, dx) - area.ang
			if absf(atan2(sin(da), cos(da))) > area.half:
				continue
		if ticked:
			if e.hit_cd > 0.0:
				continue
			e.hit_cd = 0.3
		e.hp -= dmg
		n += 1
		if e.hp <= 0.0:
			_world.kill_enemy(_game, e)
	return n


func _fire(w: Dictionary, game: GameState) -> void:
	var p: Dictionary = game.player
	var mul := game.damage_multiplier()
	var l: int = w.level
	match w.id:
		"talon":
			w.cd = rate(l, 0.55)
			var ang := atan2(p.dir_y, p.dir_x)
			var half := 0.62
			var range_px := 90.0 + 4.0 * l
			_hit({"x": p.x, "y": p.y, "r": range_px, "half": half, "ang": ang},
				(6.0 + 3.0 * l) * mul)
			arcs.append({"ang": ang, "half": half, "range": range_px, "life": 0.15, "max": 0.15})
		"ember":
			var targets := _nearest(game, 1 + int((l - 1) / 3))
			if targets.is_empty():
				w.cd = 0.0
				return
			w.cd = rate(l, 0.85)
			for t in targets:
				var d := maxf(sqrt(_dist2(t, p)), 1.0)
				bolts.append({
					"x": p.x, "y": p.y,
					"vx": (t.x - p.x) / d * BOLT_SPEED,
					"vy": (t.y - p.y) / d * BOLT_SPEED,
					"dmg": (9.0 + 4.0 * l) * mul, "life": 1.1, "r": 9.0,
				})
		"cleaver":
			var ctargets := _nearest(game, 1 + int((l - 1) / 4))
			if ctargets.is_empty():
				w.cd = 0.0
				return
			w.cd = rate(l, 1.15)
			for t in ctargets:
				var cd := maxf(sqrt(_dist2(t, p)), 1.0)
				throws.append({
					"x": p.x, "y": p.y,
					"vx": (t.x - p.x) / cd * THROW_SPEED,
					"vy": (t.y - p.y) / cd * THROW_SPEED,
					"dmg": (15.0 + 6.0 * l) * mul, "life": cd / THROW_SPEED,
					"travel": cd, "dist": 0.0, "r": 12.0,
				})
		"ward":
			w.cd = 0.45
			_hit({"x": p.x, "y": p.y, "r": 80.0}, (4.0 + 2.0 * l) * mul, true)
			rings.append({"r": 80.0, "life": 0.12, "max": 0.12})
		"spike":
			var burst_r := 56.0
			var best: Dictionary = {}
			var best_n := 0
			for cand in _world.enemies:
				var n := 0
				for e in _world.enemies:
					if _dist2(cand, e) < burst_r * burst_r:
						n += 1
				if n > best_n:
					best_n = n
					best = cand
			if best.is_empty():
				w.cd = 0.0
				return
			w.cd = rate(l, 2.6)
			_hit({"x": best.x, "y": best.y, "r": burst_r}, (18.0 + 7.0 * l) * mul)
			bursts.append({"x": best.x, "y": best.y, "r": burst_r, "life": 0.25, "max": 0.25})
		_:
			w.cd = 1.0


# Orbit positions are continuous (no cooldown): recomputed every step.
func _update_halo(w: Dictionary, dt: float, game: GameState) -> void:
	var p: Dictionary = game.player
	var mul := game.damage_multiplier()
	var count := 1 + int(ceil(w.level / 3.0))
	var radius: float = 52.0 + 3.0 * w.level
	var speed: float = 2.4 + 0.08 * w.level
	var dmg: float = (6.0 + 2.0 * w.level) * mul
	if not w.has("orbit"):
		w.orbit = 0.0
	w.orbit = fmod(w.orbit + speed * dt, TAU)
	halos.clear()
	for i in count:
		var a: float = w.orbit + i * TAU / count
		var ox: float = p.x + cos(a) * radius
		var oy: float = p.y + sin(a) * radius
		halos.append({"x": ox, "y": oy})
		_hit({"x": ox, "y": oy, "r": 17.0}, dmg, true)


# Bolts and throws are single-hit: they vanish on the frame they land.
func _step_projectiles(dt: float) -> void:
	for i in range(bolts.size() - 1, -1, -1):
		var b: Dictionary = bolts[i]
		b.x += b.vx * dt
		b.y += b.vy * dt
		b.life -= dt
		if _hit({"x": b.x, "y": b.y, "r": b.r}, b.dmg) > 0 or b.life <= 0.0:
			bolts.remove_at(i)
	for i in range(throws.size() - 1, -1, -1):
		var t: Dictionary = throws[i]
		t.x += t.vx * dt
		t.y += t.vy * dt
		t.dist += THROW_SPEED * dt
		t.life -= dt
		if _hit({"x": t.x, "y": t.y, "r": t.r}, t.dmg) > 0 or t.life <= 0.0:
			throws.remove_at(i)


func _step_fx(dt: float) -> void:
	for list in [arcs, rings, bursts]:
		for i in range(list.size() - 1, -1, -1):
			list[i].life -= dt
			if list[i].life <= 0.0:
				list.remove_at(i)
