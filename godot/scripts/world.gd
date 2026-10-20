# World entities + edge-spawn scaling + drops (plan §5 numbers).
class_name GameWorld
extends RefCounted

const BOSS_AT := 540.0 # "The Hollow Warden" spawns at 9:00

const ENEMY_TYPES := {
	"wraith": {"hp": 8.0, "spd": 55.0, "dmg": 2.0, "xp": 1.0, "sprite": "enemy-wraith"},
	"hound": {"hp": 6.0, "spd": 95.0, "dmg": 3.0, "xp": 1.0, "sprite": "enemy-hound"},
	"crawler": {"hp": 30.0, "spd": 35.0, "dmg": 5.0, "xp": 3.0, "sprite": "enemy-crawler"},
	"cultist": {"hp": 18.0, "spd": 60.0, "dmg": 6.0, "xp": 4.0, "sprite": "enemy-cultist"},
	"warden": {"hp": 3000.0, "spd": 45.0, "dmg": 12.0, "xp": 0.0, "sprite": "boss-warden", "boss": true},
}

# Minute gates at which a swarm type joins the rotation.
const GATES := [[0.0, "wraith"], [2.0, "hound"], [4.0, "crawler"], [6.0, "cultist"]]

var enemies: Array = []
var gems: Array = []
var coins: Array = []
var spawn_acc := 0.0
var boss_spawned := false


func reset() -> void:
	enemies.clear()
	gems.clear()
	coins.clear()
	spawn_acc = 0.0
	boss_spawned = false


func _types_unlocked(minutes: float) -> Array:
	var open: Array = []
	for gate in GATES:
		if minutes >= gate[0]:
			open.append(gate[1])
	return open


func _spawn_ring(view: Vector2) -> float:
	return view.length() / 2.0 + 40.0


func _spawn_enemy(type_key: String, game: GameState, view: Vector2) -> void:
	var def: Dictionary = ENEMY_TYPES[type_key]
	var angle := randf() * TAU
	var r := _spawn_ring(view)
	var hp := roundf(def.hp * (1.0 + 0.22 * (game.time / 60.0)))
	enemies.append({
		"type": type_key,
		"x": game.player.x + cos(angle) * r,
		"y": game.player.y + sin(angle) * r,
		"hp": hp,
		"max_hp": hp,
		"spd": def.spd,
		"dmg": def.dmg,
		"xp": def.xp,
		"boss": def.get("boss", false),
		"sprite": def.sprite,
		"hit_cd": 0.0, # per-enemy cooldown for lingering damage sources
	})


func update_spawns(dt: float, game: GameState, view: Vector2) -> void:
	if not boss_spawned and game.time >= BOSS_AT:
		boss_spawned = true
		_spawn_enemy("warden", game, view)
	var minute := game.time / 60.0
	spawn_acc += minf(12.0, 1.0 + 1.3 * minute) * dt
	var open := _types_unlocked(minute)
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		_spawn_enemy(open[randi() % open.size()], game, view)


# Swarmers home in on the survivor; gems magnet within Grip-scaled radius.
func update_entities(dt: float, game: GameState) -> void:
	var p: Dictionary = game.player
	for e in enemies:
		var dx: float = p.x - e.x
		var dy: float = p.y - e.y
		var d := maxf(sqrt(dx * dx + dy * dy), 1.0)
		e.x += dx / d * e.spd * dt
		e.y += dy / d * e.spd * dt
		if e.hit_cd > 0.0:
			e.hit_cd -= dt
	var magnet: float = 60.0 * (1.0 + 0.25 * game.passives.grip)
	for g in gems:
		var gx: float = p.x - g.x
		var gy: float = p.y - g.y
		var gd := maxf(sqrt(gx * gx + gy * gy), 1.0)
		if gd < magnet:
			g.x += gx / gd * 220.0 * dt
			g.y += gy / gd * 220.0 * dt
	if p.iframes > 0.0:
		p.iframes -= dt


# Death payout: ~70% gem, 6% coin (1-3g); the Warden adds +50 gold.
func kill_enemy(game: GameState, enemy: Dictionary) -> void:
	var i := enemies.find(enemy)
	if i >= 0:
		enemies.remove_at(i)
	game.kills += 1
	if enemy.boss:
		game.gold += 50
	if enemy.xp > 0.0 and randf() < 0.7:
		gems.append({"x": enemy.x, "y": enemy.y, "xp": enemy.xp})
	if randf() < 0.06:
		coins.append({"x": enemy.x, "y": enemy.y, "gold": 1 + randi() % 3})


# Consume pickups inside touch range; returns gold picked up this step.
func collect_pickups(game: GameState) -> int:
	var gold := 0
	for i in range(gems.size() - 1, -1, -1):
		var g: Dictionary = gems[i]
		if _dist(g, game.player) < 16.0:
			gems.remove_at(i)
			game.add_xp(g.xp)
	for i in range(coins.size() - 1, -1, -1):
		var c: Dictionary = coins[i]
		if _dist(c, game.player) < 16.0:
			coins.remove_at(i)
			gold += c.gold
	return gold


static func _dist(a: Dictionary, b: Dictionary) -> float:
	var dx: float = a.x - b.x
	var dy: float = a.y - b.y
	return sqrt(dx * dx + dy * dy)
