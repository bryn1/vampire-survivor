# The ONLY gameplay input path, fed from one of two sources gated here at a
# single point (OS.has_feature("web")): on web the export's head_include
# installs window keydown/keyup listeners that call on_key for every key;
# on desktop (no JavaScriptBridge/DOM) native key events feed the SAME
# held/presses queues in _input. main reads only the queues either way.
extends Node

const MOVE_KEYS := ["KeyW", "KeyA", "KeyS", "KeyD",
	"ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"]
const DISCRETE_KEYS := ["Escape", "KeyM", "Digit1", "Digit2", "Digit3",
	"Enter", "NumpadEnter", "KeyEnter"]

# Physical keys -> the DOM-style codes the queues are keyed on (desktop only;
# mirrors the e.code values the web relay forwards).
const NATIVE_CODES := {
	KEY_W: "KeyW", KEY_A: "KeyA", KEY_S: "KeyS", KEY_D: "KeyD",
	KEY_UP: "ArrowUp", KEY_DOWN: "ArrowDown", KEY_LEFT: "ArrowLeft",
	KEY_RIGHT: "ArrowRight", KEY_ESCAPE: "Escape", KEY_M: "KeyM",
	KEY_1: "Digit1", KEY_2: "Digit2", KEY_3: "Digit3",
	KEY_ENTER: "Enter", KEY_KP_ENTER: "NumpadEnter",
}

var held := {} # code -> true while the key is down
var presses: Array = [] # discrete codes, drained once per frame by main
var _native := false # true on desktop: _input feeds the queues


func _ready() -> void:
	_native = not OS.has_feature("web")


# Desktop builds only: native key events feed the same queues the DOM relay
# fills on web. Unmatched keys and auto-repeats are dropped (the web relay
# likewise ignores e.repeat).
func _input(event: InputEvent) -> void:
	if not _native:
		return
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	var code: String = NATIVE_CODES.get(key.physical_keycode, "")
	if code != "":
		on_key(code, key.pressed)


func on_key(code: String, down: bool) -> void:
	if down:
		held[code] = true
		if code in DISCRETE_KEYS:
			presses.append(code)
	else:
		held.erase(code)


func is_enter(code: String) -> bool:
	return code == "Enter" or code == "NumpadEnter" or code == "KeyEnter"


# Normalised 8-direction move vector, or ZERO when idle.
func move_vector() -> Vector2:
	var x := 0.0
	var y := 0.0
	if held.has("KeyA") or held.has("ArrowLeft"):
		x -= 1.0
	if held.has("KeyD") or held.has("ArrowRight"):
		x += 1.0
	if held.has("KeyW") or held.has("ArrowUp"):
		y -= 1.0
	if held.has("KeyS") or held.has("ArrowDown"):
		y += 1.0
	if x == 0.0 and y == 0.0:
		return Vector2.ZERO
	return Vector2(x, y).normalized()


func drain_presses() -> Array:
	var out := presses
	presses = []
	return out
