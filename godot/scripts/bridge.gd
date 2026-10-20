# JS bridge node ("vsHost"): the ONLY gameplay input path. The export's
# head_include installs window keydown/keyup listeners that call on_key for
# every key; native Input is never polled for gameplay keys.
extends Node

const MOVE_KEYS := ["KeyW", "KeyA", "KeyS", "KeyD",
	"ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"]
const DISCRETE_KEYS := ["Escape", "KeyM", "Digit1", "Digit2", "Digit3",
	"Enter", "NumpadEnter", "KeyEnter"]

var held := {} # code -> true while the key is down
var presses: Array = [] # discrete codes, drained once per frame by main


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
