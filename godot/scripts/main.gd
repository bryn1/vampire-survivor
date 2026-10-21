# Entry point: node wiring, JS bridge registration, fixed-step simulation,
# phase routing (menu/playing/levelup/end) and the Contract B snapshot eval.
extends Node2D

const VIEW := Vector2(1280, 720)

var game: GameState
var world: GameWorld
var fx: WeaponSystem
var bridge: Node
var _renderer: Node2D
var _hud: CanvasLayer
var _screens: CanvasLayer
var _current_offer: Array = []
var _web := false
var _js: Object # the JavaScriptBridge singleton, web builds only
var _js_cb: Object # keeps the inbound key callback alive


func _ready() -> void:
	game = GameState.new()
	world = GameWorld.new()
	fx = WeaponSystem.new()
	fx.bind(world, game)
	_web = OS.has_feature("web")

	_renderer = preload("res://scripts/render.gd").new()
	_renderer.game = game
	_renderer.world = world
	_renderer.fx = fx
	add_child(_renderer)

	_hud = preload("res://scripts/hud.gd").new()
	_hud.game = game
	add_child(_hud)

	_screens = preload("res://scripts/screens.gd").new()
	add_child(_screens)
	_screens.start_pressed.connect(_start_game)
	_screens.card_picked.connect(_pick)

	bridge = preload("res://scripts/bridge.gd").new()
	bridge.name = "VSHost"
	add_child(bridge)
	if _web:
		_js = Engine.get_singleton("JavaScriptBridge")
		if _js != null:
			_register_key_bridge()


# Godot 4.7 removed JavaScriptBridge.register(); the inbound path is a
# create_callback object hung on window.vsHost.on_key (same JS-side contract).
func _register_key_bridge() -> void:
	_js_cb = _js.call("create_callback", Callable(self, "_on_js_key"))
	_js.call("eval", "window.vsHost = {};", true)
	var host: Object = _js.call("get_interface", "vsHost")
	host.set("on_key", _js_cb)


func _on_js_key(args: Array) -> void:
	if args.size() >= 2:
		bridge.on_key(String(args[0]), bool(args[1]))


# Single choke point into the JS bridge: while the bridge is inactive
# (desktop builds, _js null) every call is a silent no-op. No other code
# may call JavaScriptBridge.eval.
func _js_eval(js: String) -> void:
	if _js == null:
		return
	_js.call("eval", js, true)


func _process(_delta: float) -> void:
	_hud.update()


# Snapshot + simulation run on the fixed physics tick (Contract B: time
# advances only while playing; the snapshot ships every tick).
func _physics_process(delta: float) -> void:
	_handle_presses()
	if game.phase == "playing" and not game.paused:
		_step(delta)
	_js_eval("window.__vsSnapshot=" + game.snapshot_json(world.enemies.size()))


func _handle_presses() -> void:
	for code: String in bridge.drain_presses():
		if code == "KeyM":
			game.muted = not game.muted # internal flag; this build ships no audio
		elif code == "Escape" and game.phase == "playing":
			game.paused = not game.paused
		elif game.phase == "menu" and bridge.is_enter(code):
			_start_game()
		elif game.phase == "levelup":
			if code == "Digit1":
				_pick(0)
			elif code == "Digit2":
				_pick(1)
			elif code == "Digit3":
				_pick(2)
			elif bridge.is_enter(code):
				_pick(0)
		# gameover / win: Enter deliberately does NOT restart — the score
		# panel (web) and the Play-again button own that screen.


func _step(dt: float) -> void:
	game.time += dt
	var p: Dictionary = game.player
	var v: Vector2 = bridge.move_vector()
	if v != Vector2.ZERO:
		p.dir_x = v.x
		p.dir_y = v.y
		var spd := game.player_speed()
		p.x += v.x * spd * dt
		p.y += v.y * spd * dt
	world.update_spawns(dt, game, VIEW)
	world.update_entities(dt, game)
	fx.update(dt, game)
	for e in world.enemies:
		var er: float = 55.0 if e.boss else 17.0
		var dx: float = e.x - p.x
		var dy: float = e.y - p.y
		if dx * dx + dy * dy < (er + 16.0) * (er + 16.0) and p.iframes <= 0.0:
			game.hp -= game.damage_taken(e.dmg)
			p.iframes = GameState.IFRAMES
			break
	game.gold += world.collect_pickups(game)
	if game.hp <= 0.0:
		game.hp = 0.0
		_end_run("gameover")
		return
	if game.time >= GameState.WIN_TIME:
		_end_run("win")
		return
	if game.pending_levels > 0:
		_enter_levelup()


func _start_game() -> void:
	world.reset()
	fx.clear_fx()
	game.start_run()
	_current_offer = []
	_screens.hide_all()


func _enter_levelup() -> void:
	game.set_phase("levelup")
	_current_offer = LevelUpDeck.make_offer(game)
	_screens.show_levelup(_current_offer)


func _pick(index: int) -> void:
	if game.phase != "levelup" or index < 0 or index >= _current_offer.size():
		return
	LevelUpDeck.apply_offer(game, _current_offer[index])
	game.pending_levels -= 1
	if game.pending_levels > 0:
		_current_offer = LevelUpDeck.make_offer(game)
		_screens.show_levelup(_current_offer)
		return
	_current_offer = []
	_screens.hide_all()
	game.set_phase("playing")


func _end_run(result: String) -> void:
	game.end_run(result)
	_screens.show_end(result == "win", [
		"Survived " + _fmt_time(game.stats.time),
		"Kills %d" % game.stats.kills,
		"Level %d" % game.stats.level,
		"Gold %d" % game.stats.gold,
		"Score %d" % _score(game.stats),
	])
	# The JS-side existence check keeps this a no-op even when the bridge is
	# active but the DOM submit panel was never installed (head_include absent).
	_js_eval("if (window.vsShowSubmit) vsShowSubmit(" + JSON.stringify({
		"score": _score(game.stats),
		"time_survived": roundf(game.stats.time * 10.0) / 10.0,
		"kills": game.stats.kills,
		"level": game.stats.level,
	}) + ")")


func _score(stats: Dictionary) -> int:
	return roundi(stats.time * 10.0 + stats.kills * 5.0 + stats.level * 25.0 + stats.gold)


func _fmt_time(t: float) -> String:
	var s := int(maxf(0.0, floor(t)))
	return "%02d:%02d" % [int(s / 60.0), s % 60]
