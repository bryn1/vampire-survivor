# Screens layer: menu, level-up cards and the end screen. Mouse works for
# real users; keyboard picking is routed by main from the JS bridge press
# queue (Contract B), never from here.
extends CanvasLayer

signal start_pressed
signal card_picked(index: int)

const BONE := Color8(0xd8, 0xd2, 0xc0)
const MOON := Color8(0xae, 0xbd, 0xd4)
const EMBER_TINT := Color8(0xc9, 0x7b, 0x3d)

var _menu: Control
var _levelup: Control
var _end: Control
var _end_title: Label
var _end_stats: Label
var _cards_host: HBoxContainer


func _ready() -> void:
	layer = 10
	_menu = _overlay()
	_build_menu()
	_levelup = _overlay()
	_build_levelup()
	_end = _overlay()
	_build_end()
	show_menu()


func show_menu() -> void:
	_end.visible = false
	_levelup.visible = false
	_menu.visible = true


func hide_all() -> void:
	_menu.visible = false
	_levelup.visible = false
	_end.visible = false


func show_levelup(offer: Array) -> void:
	_end.visible = false
	_menu.visible = false
	_levelup.visible = true
	for child in _cards_host.get_children():
		child.queue_free()
	for i in offer.size():
		_cards_host.add_child(_card(offer[i], i))


func show_end(win: bool, lines: Array) -> void:
	_menu.visible = false
	_levelup.visible = false
	_end.visible = true
	_end_title.text = "You survived until dawn" if win else "The night took you"
	_end_stats.text = "\n".join(lines)


func _overlay() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	return root


func _center_box(root: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(box)
	box.custom_minimum_size = Vector2(560, 0)
	box.offset_left = -280
	box.offset_right = 280
	box.offset_top = -220
	box.offset_bottom = 220
	box.add_theme_constant_override("separation", 14)
	return box


func _build_menu() -> void:
	var box := _center_box(_menu)
	box.add_child(_label("Hollow Dawn", 42, BONE))
	box.add_child(_label("Survive until dawn. Your weapons fire on their own.",
		15, MOON))
	box.add_child(_label("WASD / Arrows — move\nEsc — pause\nM — mute (no audio in this build)\n1 / 2 / 3 — choose a card",
		13, MOON))
	box.add_child(_button("Enter the night", _on_start))


func _build_levelup() -> void:
	var box := _center_box(_levelup)
	box.add_child(_label("Choose an upgrade", 24, BONE))
	_cards_host = HBoxContainer.new()
	_cards_host.add_theme_constant_override("separation", 18)
	box.add_child(_cards_host)


func _build_end() -> void:
	var box := _center_box(_end)
	_end_title = _label("", 28, BONE)
	box.add_child(_end_title)
	_end_stats = _label("", 15, MOON)
	box.add_child(_end_stats)
	box.add_child(_label("Sign the ledger in the score panel (top right).", 12, MOON))
	box.add_child(_button("Play again", _on_start))


func _card(card: Dictionary, index: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(220, 275)
	var frame := TextureRect.new()
	frame.texture = load("res://assets/card-frame.png")
	frame.custom_minimum_size = Vector2(220, 275)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(frame)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_right = -18
	box.offset_top = 24
	box.offset_bottom = -24
	holder.add_child(box)
	if card.icon != "":
		var icon := TextureRect.new()
		icon.texture = load("res://assets/" + card.icon + ".png")
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		box.add_child(icon)
	box.add_child(_label(card.name, 16, BONE))
	box.add_child(_label(card.desc, 12, MOON))
	if card.kind == "upgrade":
		box.add_child(_label("Lv %d" % card.to_level, 12, EMBER_TINT))
	box.add_child(_label(str(index + 1), 14, EMBER_TINT))
	var click := Button.new()
	click.flat = true
	click.set_anchors_preset(Control.PRESET_FULL_RECT)
	click.pressed.connect(func(): card_picked.emit(index))
	holder.add_child(click)
	return holder


func _on_start() -> void:
	start_pressed.emit()


func _button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
