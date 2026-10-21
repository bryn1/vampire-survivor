# World renderer: biome ground tiles (BIOMES band table, tiled world-locked
# behind all gameplay), sprite draws at the Contract C sizes, and transient
# weapon FX.
class_name GameRenderer
extends Node2D

const VIEW := Vector2(1280, 720)

# Plan §4 "drawn at" sizes (px, square) — native PNG size is ignored.
const SIZES := {"player": 40.0, "enemy": 34.0, "boss": 128.0, "coin": 14.0, "gem": 14.0}

const INK := Color8(0x10, 0x13, 0x1c)
const MOON := Color8(0xae, 0xbd, 0xd4)
const BONE := Color8(0xd8, 0xd2, 0xc0)
const BLOOD := Color8(0x8e, 0x2f, 0x35)
const ICHOR := Color8(0x6f, 0xae, 0x5a)
const EMBER := Color8(0xc9, 0x7b, 0x3d)
const DAWNLIGHT := Color(1.0, 0.94, 0.66) # bright warm glow of the heal pickup

# Per-type modulate so enemy silhouettes separate from the dark background
# (playthrough finding: sprites read as invisible). Alpha stays 1.0.
const ENEMY_TINTS := {
	"wraith": Color(0.62, 0.70, 0.88),
	"hound": Color(0.88, 0.72, 0.55),
	"crawler": Color(0.58, 0.80, 0.62),
	"cultist": Color(0.75, 0.62, 0.88),
	"warden": Color(1.0, 0.72, 0.45),
}

# Biome signature creatures (MC 11082): same separation rule, own hues. Kept
# as a second table because the acceptance suite pins ENEMY_TINTS to exactly
# the five classic rows; tint_of() is the single lookup both draw paths use.
const BIOME_TINTS := {
	"moor-brute": Color(0.66, 0.78, 0.48),
	"dune-scarab": Color(0.92, 0.78, 0.42),
	"rime-ghoul": Color(0.55, 0.82, 0.95),
	"pale-wight": Color(0.85, 0.82, 0.96),
}


static func tint_of(type: String) -> Color:
	return ENEMY_TINTS.get(type, BIOME_TINTS.get(type, Color.WHITE))

# Additive glow halos on enemies + Dawnlight: modulate is multiplicative, so
# a near-black sprite pixel × a pale tint stays dark. A colored aura added on
# top separates them from the background regardless of sprite darkness.
# Godot 4 has no per-draw blend switch (draw_set_blend_mode was Godot 3), so
# the halos render on HaloPass below, a child node with an additive material.
const GLOW_ALPHAS := Vector2(0.10, 0.18)   # outer, inner (enemies)
const ENEMY_GLOW_RADII := Vector2(22.0, 12.0)
const BOSS_GLOW_RADII := Vector2(40.0, 24.0)
const DAWN_GLOW_RADII := Vector2(14.0, 8.0)
const DAWN_GLOW_ALPHAS := Vector2(0.25, 0.40)

const SPRITE_NAMES := ["player", "player-alt", "enemy-wraith", "enemy-hound",
	"enemy-crawler", "enemy-cultist", "boss-warden", "coin", "gem",
	"enemies/moor-brute", "enemies/dune-scarab", "enemies/rime-ghoul",
	"enemies/pale-wight"]

# Biome bands (owner ruling MC 11077): the ground tile swaps as the run's
# clock crosses t_start; tundra carries the boss (9:00) and win (10:00) end.
# 1024px seamless tiles from static/assets/biomes, mean lum 39-55/255 — dark
# enough to keep the tinted/glowing sprites readable on top.
# Each band also fields its enemy roster (MC 11082, owner biome-enemies ask):
# the classic wraith in every band + the band's signature creature; stats and
# sprites for every id live in world.gd ENEMY_TYPES — this table is the ONE
# band source (biome_at() + these ids), read by the single spawn loop.
const BIOMES := [
	{"name": "MOORLAND", "tex": "res://assets/biomes/grass.png", "t_start": 0.0,
		"enemies": ["wraith", "moor-brute"]},
	{"name": "BURNING DUNES", "tex": "res://assets/biomes/desert.png", "t_start": 150.0,
		"enemies": ["wraith", "dune-scarab"]},
	{"name": "THE FROZEN WASTE", "tex": "res://assets/biomes/snow.png", "t_start": 300.0,
		"enemies": ["wraith", "rime-ghoul"]},
	{"name": "DEAD TUNDRA", "tex": "res://assets/biomes/tundra.png", "t_start": 450.0,
		"enemies": ["wraith", "pale-wight"]},
]


static func biome_at(t: float) -> Dictionary:
	var pick: Dictionary = BIOMES[0]
	for b in BIOMES:
		if t >= b.t_start:
			pick = b
	return pick


var game: GameState
var world: GameWorld
var fx: WeaponSystem

var _biome_tex := {} # BIOMES tex path -> Texture2D
var _sprites := {}
var _cam := Vector2.ZERO


func _ready() -> void:
	for b in BIOMES:
		_biome_tex[b.tex] = load(b.tex)
	for name in SPRITE_NAMES:
		_sprites[name] = load("res://assets/" + name + ".png")
	var glow := HaloPass.new()
	glow.host = self
	add_child(glow)


func _process(_delta: float) -> void:
	if game != null:
		_cam = Vector2(game.player.x, game.player.y) - VIEW / 2.0
	queue_redraw()


func _draw() -> void:
	if game == null or world == null:
		return
	_draw_terrain(biome_at(game.time))
	for g in world.gems:
		_draw_sprite("gem", Vector2(g.x, g.y), SIZES.gem, Color.WHITE)
	for c in world.coins:
		_draw_sprite("coin", Vector2(c.x, c.y), SIZES.coin, Color.WHITE)
	for h in world.heals:
		_draw_dawnlight(Vector2(h.x, h.y))
	for r in fx.rings:
		_draw_circle_line(VIEW / 2.0 - _cam, r.r, MOON, 3.0, 0.25 * r.life / r.max)
	for e in world.enemies:
		var size: float = SIZES.boss if e.boss else SIZES.enemy
		_draw_sprite(e.sprite, Vector2(e.x, e.y), size, tint_of(e.type))
		_draw_hp_bar(e)
	_draw_fx()
	_draw_player()
	_draw_boss_bar()


func _draw_player() -> void:
	var p: Dictionary = game.player
	var name := "player-alt" if game.level >= 5 else "player"
	var mod := Color(1, 1, 1, 0.55) if p.iframes > 0.0 else Color.WHITE
	_draw_sprite(name, Vector2(p.x, p.y), SIZES.player, mod)


func _draw_fx() -> void:
	var pc := Vector2(game.player.x, game.player.y) - _cam
	for a in fx.arcs: # Talon arcs are wedges centred on the survivor.
		var pts := PackedVector2Array([pc])
		for i in 9:
			var ang: float = a.ang - a.half + a.half * 2.0 * i / 8.0
			pts.append(pc + Vector2(cos(ang), sin(ang)) * a.range)
		draw_colored_polygon(pts, Color(MOON, 0.35 * a.life / a.max))
	for h in fx.halos:
		_draw_circle_line(Vector2(h.x, h.y) - _cam, 7.0, EMBER, 14.0, 1.0)
	for b in fx.bolts:
		_draw_circle_line(Vector2(b.x, b.y) - _cam, 5.0, EMBER, 10.0, 1.0)
	for t in fx.throws:
		var prog: float = minf(1.0, t.dist / t.travel)
		var lift := sin(PI * prog) * 26.0
		draw_rect(Rect2(Vector2(t.x, t.y) - _cam + Vector2(-8, -3) - Vector2(0, lift),
			Vector2(16, 6)), BONE)
	for b in fx.bursts:
		var r: float = b.r * (1.2 - (b.life / b.max) * 0.4)
		_draw_circle_line(Vector2(b.x, b.y) - _cam, r, ICHOR, 3.0, 0.6 * b.life / b.max)


func _draw_sprite(name: String, pos: Vector2, size: float, mod: Color) -> void:
	var screen := pos - _cam
	if screen.x < -size or screen.y < -size or screen.x > VIEW.x + size or screen.y > VIEW.y + size:
		return
	var tex: Texture2D = _sprites.get(name)
	if tex != null:
		draw_texture_rect(tex, Rect2(screen - Vector2(size, size) / 2.0, Vector2(size, size)), false, mod)
	else: # placeholder path — never crashes on a missing PNG
		draw_rect(Rect2(screen - Vector2(size, size) / 2.0, Vector2(size, size)), Color(BLOOD, mod.a))


# Dawnlight heal pickup: a small bright cross drawn programmatically (no PNG).
func _draw_dawnlight(pos: Vector2) -> void:
	const ARM := 14.0
	const BAR := 4.0
	var screen := pos - _cam
	if screen.x < -ARM or screen.y < -ARM or screen.x > VIEW.x + ARM or screen.y > VIEW.y + ARM:
		return
	draw_rect(Rect2(screen - Vector2(ARM, BAR) / 2.0, Vector2(ARM, BAR)), DAWNLIGHT)
	draw_rect(Rect2(screen - Vector2(BAR, ARM) / 2.0, Vector2(BAR, ARM)), DAWNLIGHT)


func _draw_hp_bar(e: Dictionary) -> void:
	if e.boss or e.hp >= e.max_hp:
		return
	var screen := Vector2(e.x, e.y) - _cam
	var top := screen - Vector2(14, SIZES.enemy / 2.0 + 10)
	draw_rect(Rect2(top, Vector2(28, 4)), INK)
	draw_rect(Rect2(top, Vector2(28.0 * clampf(e.hp / e.max_hp, 0.0, 1.0), 4)), BLOOD)


func _draw_boss_bar() -> void:
	var boss: Dictionary = {}
	for e in world.enemies:
		if e.boss:
			boss = e
			break
	if boss.is_empty():
		return
	var w := 420.0
	var x := (VIEW.x - w) / 2.0
	draw_rect(Rect2(x, 12, w, 10), INK)
	draw_rect(Rect2(x, 12, w * clampf(boss.hp / boss.max_hp, 0.0, 1.0), 10), EMBER)
	draw_string(ThemeDB.fallback_font, Vector2(0, 36), "THE HOLLOW WARDEN",
		HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 12, BONE)


# Biome ground: the band's 1024px tile REPEATED across the visible world rect
# [_cam, _cam+VIEW]. The rect origin is snapped to the tile grid, so the
# terrain is world-locked and pans with the camera, not screen-locked. Drawn
# first, so gameplay always stays on top; the tiles are dark by themselves
# (mean lum 39-55/255), no modulation of anything else.
func _draw_terrain(band: Dictionary) -> void:
	var tex: Texture2D = _biome_tex.get(band.tex)
	if tex == null: # placeholder path — never crashes on a missing PNG
		draw_rect(Rect2(Vector2.ZERO, VIEW), INK)
		return
	var size := Vector2(tex.get_width(), tex.get_height())
	var origin := (_cam / size).floor() * size
	draw_texture_rect(tex, Rect2(origin - _cam, _cam + VIEW - origin), true)


func _draw_circle_line(center: Vector2, radius: float, color: Color, width: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var ang := TAU * i / 24.0
		pts.append(center + Vector2(cos(ang), sin(ang)) * radius)
	draw_polyline(pts, Color(color, alpha), width)


# Additive glow pass: child node whose CanvasItemMaterial adds light instead
# of alpha-blending, so dark sprites get a bright colored aura against the
# dark background. Pulls state from the host renderer each frame; draws after
# the parent, which only brightens the overlap on top of the separation.
class HaloPass:
	extends Node2D
	var host: Node2D

	func _ready() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if host == null or host.game == null or host.world == null:
			return
		for h in host.world.heals:
			_circles(Vector2(h.x, h.y) - host._cam, GameRenderer.DAWN_GLOW_RADII,
				GameRenderer.DAWNLIGHT, GameRenderer.DAWN_GLOW_ALPHAS)
		for e in host.world.enemies:
			var radii: Vector2 = GameRenderer.BOSS_GLOW_RADII if e.boss else GameRenderer.ENEMY_GLOW_RADII
			_circles(Vector2(e.x, e.y) - host._cam, radii,
				GameRenderer.tint_of(e.type), GameRenderer.GLOW_ALPHAS)

	func _circles(screen: Vector2, radii: Vector2, tint: Color, alphas: Vector2) -> void:
		if screen.x < -radii.x or screen.y < -radii.x or screen.x > GameRenderer.VIEW.x + radii.x or screen.y > GameRenderer.VIEW.y + radii.x:
			return
		draw_circle(screen, radii.x, Color(tint, alphas.x))
		draw_circle(screen, radii.y, Color(tint, alphas.y))
