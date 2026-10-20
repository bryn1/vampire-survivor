// The six auto-fire weapons (plan §5): talon, ember, cleaver, halo, ward,
// spike. All fire without player input; level scales damage/count/rate.
// `hit(area, dmg, opts)` is injected by main.js, which owns damage + kills;
// it returns how many enemies the area damaged this step.

export const WEAPON_IDS = ["talon", "ember", "cleaver", "halo", "ward", "spike"];
export const MAX_WEAPON_LEVEL = 8;

export const WEAPON_META = {
  talon: { name: "Talon Lash", icon: "icon-talon", desc: "Raking arc in front of you" },
  ember: { name: "Ember Bolt", icon: "icon-ember", desc: "Bolts seek the nearest foe" },
  cleaver: { name: "Bone Cleaver", icon: "icon-cleaver", desc: "Heavy arcing throws" },
  halo: { name: "Cinder Halo", icon: "icon-halo", desc: "Cinders orbit around you" },
  ward: { name: "Warding Aura", icon: "icon-ward", desc: "Sears all who come close" },
  spike: { name: "Grave Spike", icon: "icon-spike", desc: "Bursts under the densest cluster" },
};

// Transient visual state read by render.js each frame.
export const fx = { bolts: [], throws: [], bursts: [], arcs: [], rings: [], halos: [] };

const BOLT_SPEED = 300;
const THROW_SPEED = 260;

// Late-bound: weapons.js must not import main/entities; main.js injects
// the live world at boot.
let worldRef = { enemies: [] };
export function bindWorld(w) {
  worldRef = w;
}

function nearestEnemies(game, count) {
  const p = game.player;
  return worldRef.enemies
    .slice()
    .sort((a, b) => dist2(a, p) - dist2(b, p))
    .slice(0, count);
}

function dist2(a, b) {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return dx * dx + dy * dy;
}

function rate(level, base) {
  return base * Math.pow(0.96, level - 1);
}

function fireWeapon(w, game, hit) {
  const p = game.player;
  const mul = 1 + 0.1 * game.passives.ferocity;
  const L = w.level;
  switch (w.id) {
    case "talon": {
      w.cd = rate(L, 0.55);
      const ang = Math.atan2(p.dirY, p.dirX);
      const half = 0.62;
      const range = 90 + 4 * L;
      hit({ kind: "circle", x: p.x, y: p.y, r: range, half, ang }, (6 + 3 * L) * mul);
      fx.arcs.push({ ang, half, range, life: 0.15, max: 0.15 });
      break;
    }
    case "ember": {
      const targets = nearestEnemies(game, 1 + Math.floor((L - 1) / 3));
      if (targets.length === 0) {
        w.cd = 0;
        return;
      }
      w.cd = rate(L, 0.85);
      for (const t of targets) {
        const d = Math.hypot(t.x - p.x, t.y - p.y) || 1;
        fx.bolts.push({
          x: p.x, y: p.y,
          vx: ((t.x - p.x) / d) * BOLT_SPEED,
          vy: ((t.y - p.y) / d) * BOLT_SPEED,
          dmg: (9 + 4 * L) * mul, life: 1.1, r: 9,
        });
      }
      break;
    }
    case "cleaver": {
      const targets = nearestEnemies(game, 1 + Math.floor((L - 1) / 4));
      if (targets.length === 0) {
        w.cd = 0;
        return;
      }
      w.cd = rate(L, 1.15);
      for (const t of targets) {
        const d = Math.hypot(t.x - p.x, t.y - p.y) || 1;
        fx.throws.push({
          x: p.x, y: p.y,
          vx: ((t.x - p.x) / d) * THROW_SPEED,
          vy: ((t.y - p.y) / d) * THROW_SPEED,
          dmg: (15 + 6 * L) * mul, life: d / THROW_SPEED, travel: d, dist: 0, r: 12,
        });
      }
      break;
    }
    case "ward": {
      w.cd = 0.45;
      hit({ kind: "circle", x: p.x, y: p.y, r: 80 }, (4 + 2 * L) * mul, { ticked: true });
      fx.rings.push({ r: 80, life: 0.12, max: 0.12 });
      break;
    }
    case "spike": {
      const r = 56;
      const enemies = worldRef.enemies;
      let best = null;
      let bestN = 0;
      for (const cand of enemies) {
        let n = 0;
        for (const e of enemies) if (dist2(cand, e) < r * r) n += 1;
        if (n > bestN) {
          bestN = n;
          best = cand;
        }
      }
      if (!best) {
        w.cd = 0;
        return;
      }
      w.cd = rate(L, 2.6);
      hit({ kind: "circle", x: best.x, y: best.y, r }, (18 + 7 * L) * mul);
      fx.bursts.push({ x: best.x, y: best.y, r, life: 0.25, max: 0.25 });
      break;
    }
    default:
      w.cd = 1;
  }
}

// Orbit positions are continuous (no cooldown): recomputed every step.
function updateHalo(w, dt, game, hit) {
  const p = game.player;
  const mul = 1 + 0.1 * game.passives.ferocity;
  const count = 1 + Math.ceil(w.level / 3);
  const radius = 52 + 3 * w.level;
  const speed = 2.4 + 0.08 * w.level;
  const dmg = (6 + 2 * w.level) * mul;
  if (w.orbit === undefined) w.orbit = 0;
  w.orbit = (w.orbit + speed * dt) % (Math.PI * 2);
  fx.halos.length = 0;
  for (let i = 0; i < count; i++) {
    const a = w.orbit + (i * Math.PI * 2) / count;
    const ox = p.x + Math.cos(a) * radius;
    const oy = p.y + Math.sin(a) * radius;
    fx.halos.push({ x: ox, y: oy });
    hit({ kind: "point", x: ox, y: oy, r: 17 }, dmg, { ticked: true });
  }
}

export function updateWeapons(dt, game, hit) {
  for (const w of game.weapons) {
    if (w.id === "halo") {
      updateHalo(w, dt, game, hit);
      continue;
    }
    w.cd -= dt;
    if (w.cd > 0) continue;
    fireWeapon(w, game, hit);
  }
  stepProjectiles(dt, hit);
  stepFx(dt);
}

function stepProjectiles(dt, hit) {
  // Bolts and throws are single-hit: they vanish on the frame they land.
  for (let i = fx.bolts.length - 1; i >= 0; i--) {
    const b = fx.bolts[i];
    b.x += b.vx * dt;
    b.y += b.vy * dt;
    b.life -= dt;
    if (hit({ kind: "point", x: b.x, y: b.y, r: b.r }, b.dmg) > 0 || b.life <= 0) {
      fx.bolts.splice(i, 1);
    }
  }
  for (let i = fx.throws.length - 1; i >= 0; i--) {
    const t = fx.throws[i];
    t.x += t.vx * dt;
    t.y += t.vy * dt;
    t.dist += THROW_SPEED * dt;
    t.life -= dt;
    if (hit({ kind: "point", x: t.x, y: t.y, r: t.r }, t.dmg) > 0 || t.life <= 0) {
      fx.throws.splice(i, 1);
    }
  }
}

function stepFx(dt) {
  for (const list of [fx.arcs, fx.rings, fx.bursts]) {
    for (let i = list.length - 1; i >= 0; i--) {
      list[i].life -= dt;
      if (list[i].life <= 0) list.splice(i, 1);
    }
  }
}
