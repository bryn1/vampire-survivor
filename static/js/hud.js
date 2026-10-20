// HUD render: timer, HP bar, XP bar + level, gold, kills, weapon icon row.
// Pure DOM updates from `game` — no game logic lives here.

import { xpNeed } from "./state.js";
import { WEAPON_META } from "./weapons.js";

const el = {};

export function initHud() {
  for (const id of [
    "hud-timer", "hud-hp-fill", "hud-hp-text", "hud-xp-fill", "hud-level",
    "hud-gold", "hud-kills", "hud-weapons", "hud-pause", "hud-mute",
  ]) {
    el[id] = document.getElementById(id);
  }
}

function fmtTime(t) {
  const s = Math.max(0, Math.floor(t));
  const mm = String(Math.floor(s / 60)).padStart(2, "0");
  const ss = String(s % 60).padStart(2, "0");
  return `${mm}:${ss}`;
}

function weaponSig(game) {
  return game.weapons.map((w) => `${w.id}${w.level}`).join(",");
}

let lastSig = null;

function renderWeaponRow(game) {
  const sig = weaponSig(game);
  if (sig === lastSig) return;
  lastSig = sig;
  el["hud-weapons"].innerHTML = game.weapons
    .map(
      (w) => `
      <span class="hud-weapon">
        <img src="./assets/${WEAPON_META[w.id].icon}.png" alt="${WEAPON_META[w.id].name}"
             width="18" height="18"
             onerror="this.outerHTML='<span class=vs-glyph>◈</span>'">
        <b>${w.level}</b>
      </span>`
    )
    .join("");
}

export function updateHud(game) {
  el["hud-timer"].textContent = fmtTime(game.time);
  const hpPct = Math.max(0, game.hp / game.maxHp);
  el["hud-hp-fill"].style.width = `${(hpPct * 100).toFixed(1)}%`;
  el["hud-hp-text"].textContent = `${Math.max(0, Math.ceil(game.hp))}/${game.maxHp}`;
  const need = xpNeed(game.level);
  el["hud-xp-fill"].style.width = `${Math.min(100, (game.xp / need) * 100).toFixed(1)}%`;
  el["hud-level"].textContent = game.level;
  el["hud-gold"].textContent = game.gold;
  el["hud-kills"].textContent = game.kills;
  renderWeaponRow(game);
  el["hud-pause"].classList.toggle("hidden", !game.paused);
  el["hud-mute"].textContent = game.muted ? "sound: off" : "sound: on";
}

// Called on run start so a finished run's icon row cannot linger.
export function resetHudRow() {
  lastSig = null;
}
