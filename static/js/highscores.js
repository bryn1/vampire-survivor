// Highscore round-trip: POST the finished run, GET the top-10 board, render
// it into the end screen. A failed fetch never breaks the stats screen —
// the rank line then reads "offline" (dispatch Contract B addendum (e)).

async function postJson(url, body) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

// Returns the rank number, or "offline" when the API is unreachable.
export async function submitScore(name, stats) {
  const clean = String(name || "").trim().slice(0, 16) || "nameless";
  try {
    const data = await postJson("/api/highscores", {
      name: clean,
      score: computeScore(stats),
      time_survived: Number(stats.time.toFixed(1)),
      kills: stats.kills,
      level: stats.level,
    });
    return data.rank;
  } catch {
    return "offline";
  }
}

// Score = seconds survived *10 + kills *5 + level *25 + gold (client-side,
// since the server contract stores the score the client submits).
export function computeScore(stats) {
  return Math.round(
    stats.time * 10 + stats.kills * 5 + stats.level * 25 + stats.gold
  );
}

export async function fetchBoard() {
  try {
    const res = await fetch("/api/highscores");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    return Array.isArray(data.scores) ? data.scores : [];
  } catch {
    return [];
  }
}

function esc(s) {
  return String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

export function renderBoard(listEl, scores) {
  if (scores.length === 0) {
    listEl.innerHTML = '<li class="board-empty">No scores yet — server offline?</li>';
    return;
  }
  listEl.innerHTML = scores
    .map(
      (row) =>
        `<li><b>${esc(row.name)}</b> · ${row.score} pts · ` +
        `${Math.floor(row.time_survived / 60)}:${String(
          Math.floor(row.time_survived % 60)
        ).padStart(2, "0")} · Lv ${row.level} · ${row.kills} kills</li>`
    )
    .join("");
}
