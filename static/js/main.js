// Entry point: boot wiring, fixed-step game loop, collision resolution,
// camera, screen routing (menu/levelup/end) and minimal WebAudio blips.
// ponytail: audio + screen routing live here because the plan's file tree
// pins the module set; upgrade path is js/audio.js + js/screens.js splits.

import {
  game, startRun, setPhase, endRun, vsState, playerSpeed,
  damageTaken, IFRAMES, WIN_TIME,
} from "./state.js";
import { moveVector, drainPresses, isEnter } from "./input.js";
import { world, resetWorld, updateSpawns, updateEntities, killEnemy, collectPickups } from "./entities.js";
import { updateWeapons, bindWorld } from "./weapons.js";
import { runLevelup, pick, hide as hideLevelup } from "./levelup.js";
import { initHud, updateHud, resetHudRow } from "./hud.js";
import { loadSprites, draw } from "./render.js";
import { submitScore, fetchBoard, renderBoard, computeScore } from "./highscores.js";

const canvas = document.getElementById("vs-canvas");
const ctx = canvas.getContext("2d");
const view = { w: 800, h: 600 };
const cam = { x: 0, y: 0, w: 800, h: 600 };

window.VS_STATE = () => vsState(world);
bindWorld(world);

function resize() {
  view.w = canvas.width = window.innerWidth;
  view.h = canvas.height = window.innerHeight;
  cam.w = view.w;
  cam.h = view.h;
}
window.addEventListener("resize", resize);
resize();

// ---------- minimal WebAudio blips (default unmuted; KeyM toggles) --------

let audioCtx = null;
let lastBlip = -1;

function ensureAudio() {
  if (audioCtx) return;
  try {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (AC) audioCtx = new AC();
  } catch {
    audioCtx = null; // no WebAudio: silence, never a crash
  }
}

function blip(freq, dur) {
  if (game.muted || !audioCtx || game.time - lastBlip < 0.09) return;
  lastBlip = game.time;
  try {
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = "triangle";
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(0.05, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + dur);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start();
    osc.stop(audioCtx.currentTime + dur);
  } catch {
    // ignore: audio is feedback, never correctness
  }
}

// ---------- damage: every weapon routes through this single entry ---------

function hit(area, dmg, opts = {}) {
  let n = 0;
  for (const e of world.enemies.slice()) {
    const er = e.boss ? 55 : 17;
    const dx = e.x - area.x;
    const dy = e.y - area.y;
    const reach = area.r + er;
    if (dx * dx + dy * dy > reach * reach) continue;
    if (area.half !== undefined) {
      const da = Math.atan2(dy, dx) - area.ang;
      if (Math.abs(Math.atan2(Math.sin(da), Math.cos(da))) > area.half) continue;
    }
    if (opts.ticked) {
      if (e.hitCd > 0) continue;
      e.hitCd = 0.3;
    }
    e.hp -= dmg;
    n += 1;
    if (e.hp <= 0) {
      killEnemy(game, e);
      blip(190, 0.06);
    }
  }
  return n;
}

function enemyTouchesPlayer(e) {
  const p = game.player;
  const er = e.boss ? 55 : 17;
  const dx = e.x - p.x;
  const dy = e.y - p.y;
  return dx * dx + dy * dy < (er + 16) * (er + 16);
}

// ---------- run lifecycle + screens ----------------------------------------

const screens = {
  menu: document.getElementById("menu-screen"),
  end: document.getElementById("end-screen"),
};

function fmt(t) {
  const s = Math.max(0, Math.floor(t));
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
}

function startGame() {
  resetWorld();
  hideLevelup();
  screens.menu.classList.add("hidden");
  screens.end.classList.add("hidden");
  resetHudRow();
  startRun();
  ensureAudio();
  lastBlip = -1;
}

let submitted = false;

function showEnd() {
  document.getElementById("end-title").textContent =
    game.phase === "win" ? "You survived until dawn" : "The night took you";
  const s = game.stats;
  document.getElementById("end-stats").innerHTML = [
    `Survived ${fmt(s.time)}`,
    `Kills ${s.kills}`,
    `Level ${s.level}`,
    `Gold ${s.gold}`,
    `Score ${computeScore(s)}`,
  ]
    .map((line) => `<li>${line}</li>`)
    .join("");
  submitted = false;
  document.getElementById("submit-button").disabled = false;
  document.getElementById("rank-line").textContent = "";
  screens.end.classList.remove("hidden");
  fetchBoard().then((rows) => renderBoard(document.getElementById("board"), rows));
}

function enterLevelup() {
  setPhase("levelup");
  blip(440, 0.15);
  runLevelup(game, () => setPhase("playing"));
}

// ---------- per-step simulation (fixed dt only, never wall-clock) ---------

function step(dt) {
  if (game.phase !== "playing" || game.paused) return;
  game.time += dt;
  const p = game.player;
  const v = moveVector();
  if (v) {
    p.dirX = v.x;
    p.dirY = v.y;
    const spd = playerSpeed();
    p.x += v.x * spd * dt;
    p.y += v.y * spd * dt;
  }
  updateSpawns(dt, game, view);
  updateEntities(dt, game);
  updateWeapons(dt, game, hit);
  for (const e of world.enemies) {
    if (enemyTouchesPlayer(e) && p.iframes <= 0) {
      game.hp -= damageTaken(e.dmg);
      p.iframes = IFRAMES;
      blip(110, 0.12);
      break;
    }
  }
  game.gold += collectPickups(game);
  if (game.hp <= 0) {
    game.hp = 0;
    endRun("gameover");
    showEnd();
    return;
  }
  if (game.time >= WIN_TIME) {
    endRun("win");
    showEnd();
    return;
  }
  if (game.pendingLevels > 0) enterLevelup();
}

// ---------- discrete input routed by phase (Contract B + addendum a) ------

function handlePresses() {
  for (const code of drainPresses()) {
    if (code === "KeyM") {
      game.muted = !game.muted;
    } else if (code === "Escape" && game.phase === "playing") {
      game.paused = !game.paused;
    } else if (game.phase === "menu" && isEnter(code)) {
      startGame();
    } else if (game.phase === "levelup") {
      if (code === "Digit1") pick(0);
      else if (code === "Digit2") pick(1);
      else if (code === "Digit3") pick(2);
      else if (isEnter(code)) pick(0);
    }
    // gameover / win: Enter deliberately does NOT restart — the name-submit
    // form and the Play-again button own that screen.
  }
}

// ---------- fixed-step loop -------------------------------------------------

const FIXED = 1 / 60;
let acc = 0;
let last = performance.now();

function frame(now) {
  requestAnimationFrame(frame);
  acc = Math.min(acc + (now - last) / 1000, 0.25);
  last = now;
  handlePresses();
  while (acc >= FIXED) {
    acc -= FIXED;
    step(FIXED);
  }
  cam.x = game.player.x - view.w / 2;
  cam.y = game.player.y - view.h / 2;
  draw(ctx, game, cam);
  updateHud(game);
}

// ---------- screen wiring ----------------------------------------------------

canvas.addEventListener("click", () => {
  if (game.phase === "menu") startGame();
});
document.getElementById("start-button").addEventListener("click", startGame);
document.getElementById("again-button").addEventListener("click", startGame);

document.getElementById("score-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  if (submitted || !game.stats) return;
  submitted = true;
  document.getElementById("submit-button").disabled = true;
  const rank = await submitScore(document.getElementById("score-name").value, game.stats);
  document.getElementById("rank-line").textContent =
    typeof rank === "number"
      ? `Rank #${rank} — inscribed on the ledger.`
      : "Rank: offline — leaderboard unreachable.";
  renderBoard(document.getElementById("board"), await fetchBoard());
});

initHud();
loadSprites();
requestAnimationFrame(frame);
