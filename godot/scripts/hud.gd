# HUD: timer, HP bar, XP bar + level, gold, kills, weapon icon row, and the
# biome-name banner. Pure display — built in code, updated from GameState
# every frame.
extends CanvasLayer

const INK := Color8(0x10, 0x13, 0x1c)
const BLOOD := Color8(0x8e, 0x2f, 0x35)
const ICHOR := Color8(0x6f, 0xae, 0x5a)
const BONE := Color8(0xd8, 0xd2, 0xc0)
const EMBER_TINT := Color8(0xc9, 0x7b, 0x3d)

const BIOME_FLASH := 3.0 # seconds the biome-name banner stays up, fading last 1s

var game: GameState

var _timer: Label
var _hp_fill: ColorRect
var _hp_text: Label
var _xp_fill: ColorRect
var _level: Label
var _gold: Label
var _kills: Label
var _weapons: HBoxContainer
var _pause: Label
var _biome: Label
var _biome_name := ""
var _biome_left := 0.0
var _row_sig := ""


func _ready() -> void:
	layer = 5
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	_timer = _label("00:00")
	row.add_child(_timer)
	row.add_child(_bar("hp", 160))
	row.add_child(_bar("xp", 160))
	_level = _label("Lv 1")
	row.add_child(_level)
	_gold = _label("Gold 0")
	row.add_child(_gold)
	_kills = _label("Kills 0")
	row.add_child(_kills)
	_weapons = HBoxContainer.new()
	_weapons.add_theme_constant_override("separation", 4)
	row.add_child(_weapons)
	_pause = _label("PAUSED")
	_pause.modulate = EMBER_TINT
	_pause.visible = false
	row.add_child(_pause)
	_biome = _label("")
	_biome.add_theme_font_size_override("font_size", 26)
	_biome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_biome.position = Vector2(0, 140)
	_biome.size = Vector2(GameRenderer.VIEW.x, 40)
	_biome.modulate.a = 0.0
	add_child(_biome)


func update(delta: float) -> void:
	if game == null:
		return
	_timer.text = _fmt_time(game.time)
	_hp_fill.size = Vector2(158.0 * clampf(game.hp / game.max_hp, 0.0, 1.0), 14)
	_hp_text.text = "%d/%d" % [int(maxf(0.0, ceil(game.hp))), int(game.max_hp)]
	var need := float(GameState.xp_need(game.level))
	_xp_fill.size = Vector2(158.0 * clampf(game.xp / need, 0.0, 1.0), 14)
	_level.text = "Lv %d" % game.level
	_gold.text = "Gold %d" % game.gold
	_kills.text = "Kills %d" % game.kills
	_pause.visible = game.paused and game.phase == "playing"
	_render_weapon_row()
	_update_biome_flash(delta)


# Biome banner (MC 11077): on every band change (game.time crossing a BIOMES
# t_start, read via the one GameRenderer.biome_at mechanism) the band name
# flashes full-alpha and fades out over BIOME_FLASH seconds.
func _update_biome_flash(delta: float) -> void:
	if game.phase != "playing":
		_biome_name = "" # re-arm: the next run flashes its first band
	else:
		var band: Dictionary = GameRenderer.biome_at(game.time)
		if band.name != _biome_name:
			_biome_name = band.name
			_biome.text = _biome_name
			_biome_left = BIOME_FLASH
	if _biome_left > 0.0:
		_biome_left = maxf(0.0, _biome_left - delta)
		_biome.modulate.a = clampf(_biome_left, 0.0, 1.0)


func _render_weapon_row() -> void:
	var sig := ""
	for w in game.weapons:
		sig += w.id + str(w.level) + ","
	if sig == _row_sig:
		return
	_row_sig = sig
	for child in _weapons.get_children():
		child.queue_free()
	for w in game.weapons:
		var cell := VBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = load("res://assets/" + WeaponSystem.META[w.id].icon + ".png")
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(icon)
		var lv := _label(str(w.level))
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(lv)
		_weapons.add_child(cell)


func _bar(kind: String, width: float) -> Control:
	var track := Control.new()
	track.custom_minimum_size = Vector2(width, 16)
	track.clip_contents = true
	var bg := ColorRect.new()
	bg.color = Color(INK, 0.9)
	bg.size = Vector2(width - 2.0, 14)
	bg.position = Vector2.ONE
	track.add_child(bg)
	var fill := ColorRect.new()
	fill.color = BLOOD if kind == "hp" else ICHOR
	fill.position = Vector2.ONE
	fill.size = Vector2(width - 2.0, 14)
	track.add_child(fill)
	if kind == "hp":
		_hp_fill = fill
		_hp_text = _label("100/100")
		_hp_text.add_theme_font_size_override("font_size", 10)
		_hp_text.position = Vector2(4, 1)
		track.add_child(_hp_text)
	else:
		_xp_fill = fill
	return track


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", BONE)
	return label


func _fmt_time(t: float) -> String:
	var s := int(maxf(0.0, floor(t)))
	return "%02d:%02d" % [int(s / 60.0), s % 60]
