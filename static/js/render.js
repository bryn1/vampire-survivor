// Canvas renderer: sprite loading that never crashes on a missing PNG
// (tinted rounded-rect placeholders instead), Contract C draw sizes, and
// the procedural background (radial ink→slate gradient + vignette + grid).

import { world } from "./entities.js";
import { fx } from "./weapons.js";

const SPRITES = [
  "player", "player-alt", "enemy-wraith", "enemy-hound", "enemy-crawler",
  "enemy-cultist", "boss-warden", "coin", "gem",
];

// Plan §4 "drawn at" sizes (px, square) — native PNG size is ignored.
const SIZES = {
  player: 40, "player-alt": 40, boss: 128, enemy: 34, coin: 14, gem: 14,
};

const PLACEHOLDER_TINT = {
  player: "#8e2f35", "player-alt": "#8e2f35",
  "boss-warden": "#c97b3d", coin: "#d8d2c0", gem: "#6fae5a",
};

const sprites = new Map();

export function loadSprites() {
  for (const name of SPRITES) {
    const entry = { img: null, ok: false };
    sprites.set(name, entry);
    const img = new Image();
    img.onload = () => {
      entry.img = img;
      entry.ok = true;
    };
    img.onerror = () => {
      entry.img = null;
      entry.ok = false; // placeholder path — never throws
    };
    img.src = `./assets/${name}.png`;
  }
}

function roundRectPath(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function drawSprite(ctx, name, x, y, size, cam) {
  const sx = x - cam.x;
  const sy = y - cam.y;
  if (sx < -size || sy < -size || sx > cam.w + size || sy > cam.h + size) return;
  const entry = sprites.get(name);
  if (entry && entry.ok) {
    ctx.drawImage(entry.img, sx - size / 2, sy - size / 2, size, size);
    return;
  }
  const tint = PLACEHOLDER_TINT[name] || "#2a3140";
  ctx.fillStyle = tint;
  roundRectPath(ctx, sx - size / 2, sy - size / 2, size, size, size * 0.28);
  ctx.fill();
}

function drawBackground(ctx, cam) {
  const g = ctx.createRadialGradient(
    cam.w / 2, cam.h / 2, 60, cam.w / 2, cam.h / 2, Math.hypot(cam.w, cam.h) * 0.7
  );
  g.addColorStop(0, "#232b3a");
  g.addColorStop(1, "#10131c");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, cam.w, cam.h);

  ctx.strokeStyle = "rgba(174, 189, 212, 0.055)";
  ctx.lineWidth = 1;
  const step = 64;
  const ox = -cam.x % step;
  const oy = -cam.y % step;
  ctx.beginPath();
  for (let x = ox; x < cam.w; x += step) {
    ctx.moveTo(x, 0);
    ctx.lineTo(x, cam.h);
  }
  for (let y = oy; y < cam.h; y += step) {
    ctx.moveTo(0, y);
    ctx.lineTo(cam.w, y);
  }
  ctx.stroke();

  const v = ctx.createRadialGradient(
    cam.w / 2, cam.h / 2, Math.min(cam.w, cam.h) * 0.35,
    cam.w / 2, cam.h / 2, Math.hypot(cam.w, cam.h) * 0.62
  );
  v.addColorStop(0, "rgba(0,0,0,0)");
  v.addColorStop(1, "rgba(0,0,0,0.55)");
  ctx.fillStyle = v;
  ctx.fillRect(0, 0, cam.w, cam.h);
}

function drawHpBar(ctx, e, cam) {
  if (e.boss || e.hp >= e.maxHp) return;
  const sx = e.x - cam.x;
  const sy = e.y - cam.y - SIZES.enemy / 2 - 6;
  ctx.fillStyle = "#10131c";
  ctx.fillRect(sx - 14, sy, 28, 4);
  ctx.fillStyle = "#8e2f35";
  ctx.fillRect(sx - 14, sy, 28 * Math.max(0, e.hp / e.maxHp), 4);
}

function drawWeaponFx(ctx, game, cam) {
  // Talon arcs are wedges centred on the survivor.
  const px = game.player.x - cam.x;
  const py = game.player.y - cam.y;
  for (const a of fx.arcs) {
    ctx.save();
    ctx.globalAlpha = 0.35 * (a.life / a.max);
    ctx.fillStyle = "#aebdd4";
    ctx.beginPath();
    ctx.moveTo(px, py);
    ctx.arc(px, py, a.range, a.ang - a.half, a.ang + a.half);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }
}

export function draw(ctx, game, cam) {
  drawBackground(ctx, cam);
  for (const g of world.gems) drawSprite(ctx, "gem", g.x, g.y, SIZES.gem, cam);
  for (const c of world.coins) drawSprite(ctx, "coin", c.x, c.y, SIZES.coin, cam);

  ctx.save();
  for (const r of fx.rings) {
    ctx.globalAlpha = 0.25 * (r.life / r.max);
    ctx.strokeStyle = "#aebdd4";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(game.player.x - cam.x, game.player.y - cam.y, r.r, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.restore();

  for (const e of world.enemies) {
    const size = e.boss ? SIZES.boss : SIZES.enemy;
    drawSprite(ctx, e.sprite, e.x, e.y, size, cam);
    drawHpBar(ctx, e, cam);
  }

  drawWeaponFx(ctx, game, cam);
  drawPlayer(ctx, game, cam);
  drawProjectiles(ctx, cam);

  for (const b of fx.bursts) {
    ctx.save();
    ctx.globalAlpha = 0.6 * (b.life / b.max);
    ctx.strokeStyle = "#6fae5a";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(b.x - cam.x, b.y - cam.y, b.r * (1.2 - (b.life / b.max) * 0.4), 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  drawBossBar(ctx, cam);
}

function drawPlayer(ctx, game, cam) {
  const p = game.player;
  const name = game.level >= 5 ? "player-alt" : "player";
  ctx.save();
  if (p.iframes > 0) ctx.globalAlpha = 0.55;
  drawSprite(ctx, name, p.x, p.y, SIZES.player, cam);
  ctx.restore();
}

function drawProjectiles(ctx, cam) {
  for (const h of fx.halos) {
    ctx.fillStyle = "#c97b3d";
    ctx.beginPath();
    ctx.arc(h.x - cam.x, h.y - cam.y, 7, 0, Math.PI * 2);
    ctx.fill();
  }
  for (const b of fx.bolts) {
    ctx.fillStyle = "#c97b3d";
    ctx.beginPath();
    ctx.arc(b.x - cam.x, b.y - cam.y, 5, 0, Math.PI * 2);
    ctx.fill();
  }
  for (const t of fx.throws) {
    const prog = Math.min(1, t.dist / t.travel);
    const lift = Math.sin(Math.PI * prog) * 26;
    ctx.save();
    ctx.translate(t.x - cam.x, t.y - cam.y - lift);
    ctx.rotate(prog * Math.PI * 3);
    ctx.fillStyle = "#d8d2c0";
    ctx.fillRect(-8, -3, 16, 6);
    ctx.restore();
  }
}

function drawBossBar(ctx, cam) {
  const boss = world.enemies.find((e) => e.boss);
  if (!boss) return;
  const w = Math.min(420, cam.w - 40);
  const x = (cam.w - w) / 2;
  ctx.fillStyle = "#10131c";
  ctx.fillRect(x, 12, w, 10);
  ctx.fillStyle = "#c97b3d";
  ctx.fillRect(x, 12, w * Math.max(0, boss.hp / boss.maxHp), 10);
  ctx.fillStyle = "#d8d2c0";
  ctx.font = "12px sans-serif";
  ctx.textAlign = "center";
  ctx.fillText("THE HOLLOW WARDEN", cam.w / 2, 36);
}
