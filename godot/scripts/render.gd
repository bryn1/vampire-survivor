# World renderer: procedural background (radial ink→slate gradient +
# vignette), sprite draws at the Contract C sizes, and transient weapon FX.
extends Node2D

const VIEW := Vector2(1280, 720)
const BG_SAMPLES := Vector2i(320, 180)

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

const SPRITE_NAMES := ["player", "player-alt", "enemy-wraith", "enemy-hound",
	"enemy-crawler", "enemy-cultist", "boss-warden", "coin", "gem"]

var game: GameState
var world: GameWorld
var fx: WeaponSystem

var _bg: ImageTexture
var _sprites := {}
var _cam := Vector2.ZERO


func _ready() -> void:
	_bg = _build_background()
	for name in SPRITE_NAMES:
		_sprites[name] = load("res://assets/" + name + ".png")


func _process(_delta: float) -> void:
	if game != null:
		_cam = Vector2(game.player.x, game.player.y) - VIEW / 2.0
	queue_redraw()


func _draw() -> void:
	if game == null or world == null:
		return
	draw_texture_rect(_bg, Rect2(Vector2.ZERO, VIEW), false)
	_draw_grid()
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
		_draw_sprite(e.sprite, Vector2(e.x, e.y), size, ENEMY_TINTS.get(e.type, Color.WHITE))
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


func _draw_grid() -> void:
	const STEP := 64.0
	var ox := fposmod(-_cam.x, STEP)
	var oy := fposmod(-_cam.y, STEP)
	var col := Color(MOON, 0.055)
	var x := ox
	while x < VIEW.x:
		draw_line(Vector2(x, 0), Vector2(x, VIEW.y), col, 1.0)
		x += STEP
	var y := oy
	while y < VIEW.y:
		draw_line(Vector2(0, y), Vector2(VIEW.x, y), col, 1.0)
		y += STEP


func _draw_circle_line(center: Vector2, radius: float, color: Color, width: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var ang := TAU * i / 24.0
		pts.append(center + Vector2(cos(ang), sin(ang)) * radius)
	draw_polyline(pts, Color(color, alpha), width)


# Bakes the radial ink→slate gradient + vignette once into a small texture.
func _build_background() -> ImageTexture:
	var img := Image.create(BG_SAMPLES.x, BG_SAMPLES.y, false, Image.FORMAT_RGB8)
	var grad_inner := Color8(0x23, 0x2b, 0x3a)
	var center := Vector2(BG_SAMPLES.x, BG_SAMPLES.y) / 2.0
	var scale := BG_SAMPLES.x / VIEW.x
	var r0 := 60.0 * scale
	var r1 := VIEW.length() * 0.7 * scale
	var rv0 := minf(VIEW.x, VIEW.y) * 0.35 * scale
	var rv1 := VIEW.length() * 0.62 * scale
	for py in BG_SAMPLES.y:
		for px in BG_SAMPLES.x:
			var d := center.distance_to(Vector2(px, py))
			var t := clampf((d - r0) / (r1 - r0), 0.0, 1.0)
			var col := grad_inner.lerp(INK, t)
			var va := clampf((d - rv0) / (rv1 - rv0), 0.0, 1.0) * 0.55
			img.set_pixel(px, py, col.lerp(Color.BLACK, va))
	return ImageTexture.create_from_image(img)
