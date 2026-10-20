// World entities + edge-spawn scaling + drops (plan §5 numbers).

import { addXp } from "./state.js";

export const world = { enemies: [], gems: [], coins: [] };

const BOSS_AT = 540; // "The Hollow Warden" spawns at 9:00

export const ENEMY_TYPES = {
  wraith: { hp: 8, spd: 55, dmg: 2, xp: 1, sprite: "enemy-wraith" },
  hound: { hp: 6, spd: 95, dmg: 3, xp: 1, sprite: "enemy-hound" },
  crawler: { hp: 30, spd: 35, dmg: 5, xp: 3, sprite: "enemy-crawler" },
  cultist: { hp: 18, spd: 60, dmg: 6, xp: 4, sprite: "enemy-cultist" },
  warden: { hp: 3000, spd: 45, dmg: 12, xp: 0, sprite: "boss-warden", boss: true },
};

// Minute gates at which a swarm type joins the rotation.
const GATES = [
  [0, "wraith"],
  [2, "hound"],
  [4, "crawler"],
  [6, "cultist"],
];

let spawnAcc = 0;
let bossSpawned = false;

export function resetWorld() {
  world.enemies.length = 0;
  world.gems.length = 0;
  world.coins.length = 0;
  spawnAcc = 0;
  bossSpawned = false;
}

function typesUnlocked(minutes) {
  const open = [];
  for (const [gate, type] of GATES) if (minutes >= gate) open.push(type);
  return open;
}

function spawnRing(view) {
  return Math.hypot(view.w, view.h) / 2 + 40;
}

function spawnEnemy(typeKey, game, view) {
  const def = ENEMY_TYPES[typeKey];
  const angle = Math.random() * Math.PI * 2;
  const r = spawnRing(view);
  const hp = Math.round(def.hp * (1 + 0.22 * (game.time / 60)));
  world.enemies.push({
    type: typeKey,
    x: game.player.x + Math.cos(angle) * r,
    y: game.player.y + Math.sin(angle) * r,
    hp,
    maxHp: hp,
    spd: def.spd,
    dmg: def.dmg,
    xp: def.xp,
    boss: !!def.boss,
    sprite: def.sprite,
    hitCd: 0, // per-enemy cooldown for lingering damage sources
  });
}

export function updateSpawns(dt, game, view) {
  if (!bossSpawned && game.time >= BOSS_AT) {
    bossSpawned = true;
    spawnEnemy("warden", game, view);
  }
  const minute = game.time / 60;
  spawnAcc += Math.min(12, 1 + 1.3 * minute) * dt;
  const open = typesUnlocked(minute);
  while (spawnAcc >= 1) {
    spawnAcc -= 1;
    spawnEnemy(open[(Math.random() * open.length) | 0], game, view);
  }
}

// Swarmers home in on the survivor; gems magnet within Grip-scaled radius.
export function updateEntities(dt, game) {
  const p = game.player;
  for (const e of world.enemies) {
    const dx = p.x - e.x;
    const dy = p.y - e.y;
    const d = Math.hypot(dx, dy) || 1;
    e.x += (dx / d) * e.spd * dt;
    e.y += (dy / d) * e.spd * dt;
    if (e.hitCd > 0) e.hitCd -= dt;
  }
  const magnet = 60 * (1 + 0.25 * game.passives.grip);
  for (const g of world.gems) {
    const dx = p.x - g.x;
    const dy = p.y - g.y;
    const d = Math.hypot(dx, dy) || 1;
    if (d < magnet) {
      const pull = 220;
      g.x += (dx / d) * pull * dt;
      g.y += (dy / d) * pull * dt;
    }
  }
  if (p.iframes > 0) p.iframes -= dt;
}

function removeAt(list, i) {
  list.splice(i, 1);
}

// Death payout: ~70% gem, 6% coin (1-3g); the Warden adds +50 gold.
export function killEnemy(game, enemy) {
  const i = world.enemies.indexOf(enemy);
  if (i >= 0) removeAt(world.enemies, i);
  game.kills += 1;
  if (enemy.boss) game.gold += 50;
  if (enemy.xp > 0 && Math.random() < 0.7) {
    world.gems.push({ x: enemy.x, y: enemy.y, xp: enemy.xp });
  }
  if (Math.random() < 0.06) {
    world.coins.push({ x: enemy.x, y: enemy.y, gold: 1 + ((Math.random() * 3) | 0) });
  }
}

// Consume pickups inside touch range; returns gold picked up this step.
export function collectPickups(game) {
  let gold = 0;
  for (let i = world.gems.length - 1; i >= 0; i--) {
    const g = world.gems[i];
    if (Math.hypot(g.x - game.player.x, g.y - game.player.y) < 16) {
      removeAt(world.gems, i);
      addXp(g.xp);
    }
  }
  for (let i = world.coins.length - 1; i >= 0; i--) {
    const c = world.coins[i];
    if (Math.hypot(c.x - game.player.x, c.y - game.player.y) < 16) {
      removeAt(world.coins, i);
      gold += c.gold;
    }
  }
  return gold;
}
