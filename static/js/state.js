// Run state + phase machine + the window.VS_STATE debug hook (Contract B).

export const game = {
  phase: "menu", // menu | playing | levelup | gameover | win
  paused: false, // Esc freeze; not a phase value (Contract B)
  muted: false,
  time: 0, // seconds, advances only while playing and not paused
  runId: "",
  hp: 100,
  maxHp: 100,
  level: 1,
  xp: 0,
  gold: 0,
  kills: 0,
  pendingLevels: 0,
  weapons: [], // [{id, level, cd}] — ids per plan §5
  passives: { ferocity: 0, haste: 0, ward: 0, grip: 0, insight: 0 },
  player: { x: 0, y: 0, dirX: 1, dirY: 0, iframes: 0 },
  stats: null, // frozen end-of-run stats for the end screens
};

const BASE_SPEED = 140;
export const IFRAMES = 0.5;
export const WIN_TIME = 600;

// Contract B curve: xp needed to go from `level` to the next one.
export function xpNeed(level) {
  return 5 + 4 * level + level * level;
}

export function playerSpeed() {
  return BASE_SPEED * (1 + 0.08 * game.passives.haste);
}

export function damageTaken(raw) {
  return Math.max(0, raw - game.passives.ward);
}

export function startRun() {
  game.phase = "playing";
  game.paused = false;
  game.time = 0;
  game.runId = crypto.randomUUID();
  game.hp = 100;
  game.maxHp = 100;
  game.level = 1;
  game.xp = 0;
  game.gold = 0;
  game.kills = 0;
  game.pendingLevels = 0;
  game.weapons = [{ id: "talon", level: 1, cd: 0 }];
  game.passives = { ferocity: 0, haste: 0, ward: 0, grip: 0, insight: 0 };
  game.player = { x: 0, y: 0, dirX: 1, dirY: 0, iframes: 0 };
  game.stats = null;
}

export function setPhase(phase) {
  game.phase = phase;
  game.paused = false;
}

export function endRun(result) {
  game.stats = {
    time: game.time,
    kills: game.kills,
    level: game.level,
    gold: game.gold,
  };
  game.phase = result; // "gameover" | "win"
}

// Insight multiplies gained xp; overflow may raise several levels at once.
export function addXp(amount) {
  game.xp += amount * (1 + 0.15 * game.passives.insight);
  while (game.xp >= xpNeed(game.level)) {
    game.xp -= xpNeed(game.level);
    game.level += 1;
    game.pendingLevels += 1;
  }
}

// Exact Contract B shape, field for field. `world` supplies the enemy count.
export function vsState(world) {
  return {
    phase: game.phase,
    hp: game.hp,
    maxHp: game.maxHp,
    level: game.level,
    xp: game.xp,
    xpNext: xpNeed(game.level),
    gold: game.gold,
    kills: game.kills,
    time: game.time,
    enemies: world.enemies.length,
    weapons: game.weapons.map((w) => ({ id: w.id, level: w.level })),
    runId: game.runId,
  };
}
