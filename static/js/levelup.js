// XP-driven level-up: builds the 3-card offer, renders it as DOM cards and
// applies the pick (plan §5 pool: weapon, weapon level+1, passive).

import { MAX_WEAPON_LEVEL, WEAPON_IDS, WEAPON_META } from "./weapons.js";
import { game } from "./state.js";

const MAX_PASSIVE_STACKS = 5;

const PASSIVES = [
  { key: "ferocity", name: "Ferocity", desc: "+10% weapon damage" },
  { key: "haste", name: "Haste", desc: "+8% move speed" },
  { key: "ward", name: "Warding", desc: "-1 damage taken" },
  { key: "grip", name: "Grip", desc: "+25% pickup radius" },
  { key: "insight", name: "Insight", desc: "+15% xp gain" },
];

function buildPool(game) {
  const pool = [];
  for (const id of WEAPON_IDS) {
    const owned = game.weapons.find((w) => w.id === id);
    const meta = WEAPON_META[id];
    if (!owned) {
      pool.push({ kind: "weapon", id, name: meta.name, desc: meta.desc, icon: meta.icon });
    } else if (owned.level < MAX_WEAPON_LEVEL) {
      pool.push({
        kind: "upgrade", id,
        name: meta.name, desc: meta.desc, icon: meta.icon,
        toLevel: owned.level + 1,
      });
    }
  }
  for (const p of PASSIVES) {
    if (game.passives[p.key] < MAX_PASSIVE_STACKS) {
      pool.push({ kind: "passive", key: p.key, name: p.name, desc: p.desc, icon: null });
    }
  }
  return pool;
}

function shuffled(list) {
  const a = list.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = (Math.random() * (i + 1)) | 0;
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// Nothing left to grant (everything capped): offer a rich consolation.
function bonusCard() {
  return { kind: "bonus", name: "Coin Cache", desc: "+25 gold, +10 hp", icon: "coin" };
}

function applyOffer(game, card) {
  if (card.kind === "weapon") {
    game.weapons.push({ id: card.id, level: 1, cd: 0 });
  } else if (card.kind === "upgrade") {
    const w = game.weapons.find((x) => x.id === card.id);
    if (w && w.level < MAX_WEAPON_LEVEL) w.level += 1;
  } else if (card.kind === "passive") {
    game.passives[card.key] += 1;
  } else {
    game.gold += 25;
    game.hp = Math.min(game.maxHp, game.hp + 10);
  }
}

function iconHtml(card) {
  if (!card.icon) return '<span class="vs-glyph">✦</span>';
  return `<img class="vs-icon" src="./assets/${card.icon}.png" alt="" width="22" height="22"
    onerror="this.outerHTML='<span class=vs-glyph>◈</span>'">`;
}

function cardHtml(card, index) {
  const levelTag = card.kind === "upgrade" ? `<span class="vs-lv">Lv ${card.toLevel}</span>` : "";
  return `
    <div class="vs-card" data-card="${index}"
         style="background-image:url(./assets/card-frame.png)">
      ${iconHtml(card)}
      <h3>${card.name}</h3>
      <p>${card.desc}</p>
      ${levelTag}
      <span class="vs-key">${index + 1}</span>
    </div>`;
}

let current = null; // { cards, onDone } while the level-up screen is open

export function runLevelup(game, onDone) {
  const pool = shuffled(buildPool(game));
  const cards = [0, 1, 2].map((i) => pool[i] || bonusCard());
  current = { cards, onDone };
  const holder = document.getElementById("levelup-cards");
  holder.innerHTML = cards.map(cardHtml).join("");
  holder.querySelectorAll(".vs-card").forEach((el) => {
    el.addEventListener("click", () => pick(Number(el.dataset.card)));
  });
  document.getElementById("levelup-screen").classList.remove("hidden");
}

// Contract B: Digit1/2/3 or .vs-card clicks pick a card; Enter picks card 0
// (main.js routes that here as pick(0)).
export function pick(index) {
  if (!current || index < 0 || index >= current.cards.length) return;
  const { cards, onDone } = current;
  applyOffer(game, cards[index]);
  game.pendingLevels -= 1;
  if (game.pendingLevels > 0) {
    runLevelup(game, onDone);
    return;
  }
  hide();
  onDone();
}

export function hide() {
  current = null;
  document.getElementById("levelup-screen").classList.add("hidden");
}
