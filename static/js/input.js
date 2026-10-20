// Keyboard contract (Contract B): window-level listeners, e.code matching.
// Movement is continuous (held keys); everything else queues discrete
// presses that main.js drains once per frame. Synthetic KeyboardEvents
// dispatched on window drive the whole game.

const MOVE = new Set([
  "KeyW", "KeyA", "KeyS", "KeyD",
  "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight",
]);

const DISCRETE = new Set([
  "Escape", "KeyM", "Digit1", "Digit2", "Digit3",
  // Enter arrives under three codes depending on origin (KeyboardEvent.code,
  // Numpad, or a synthetic harness using "KeyEnter"); all mean the same pick.
  "Enter", "NumpadEnter", "KeyEnter",
]);

const held = new Set();
const presses = [];

// Keys typed into the score-name field must not steer the survivor.
function isTyping(e) {
  const t = e.target;
  return !!t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable);
}

window.addEventListener("keydown", (e) => {
  if (isTyping(e)) return;
  const code = e.code;
  if (MOVE.has(code) || DISCRETE.has(code)) e.preventDefault();
  if (DISCRETE.has(code) && !e.repeat) presses.push(code);
  held.add(code);
});

window.addEventListener("keyup", (e) => {
  if (isTyping(e)) return;
  held.delete(e.code);
});

export function isEnter(code) {
  return code === "Enter" || code === "NumpadEnter" || code === "KeyEnter";
}

// Normalised 8-direction move vector, or null when idle.
export function moveVector() {
  let x = 0;
  let y = 0;
  if (held.has("KeyA") || held.has("ArrowLeft")) x -= 1;
  if (held.has("KeyD") || held.has("ArrowRight")) x += 1;
  if (held.has("KeyW") || held.has("ArrowUp")) y -= 1;
  if (held.has("KeyS") || held.has("ArrowDown")) y += 1;
  if (x === 0 && y === 0) return null;
  const inv = 1 / Math.hypot(x, y);
  return { x: x * inv, y: y * inv };
}

// Codes pressed since the last drain (each discrete code once per press).
export function drainPresses() {
  return presses.splice(0, presses.length);
}
