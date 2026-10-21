<script>
window.__vsSnapshot = null;
window.VS_STATE = function () { return window.__vsSnapshot; };
(function () {
  function relay(e) {
    var t = e.target;
    if (t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable)) return;
    if (e.type === "keydown" && e.repeat) return;
    if (window.vsHost && window.vsHost.on_key) window.vsHost.on_key(String(e.code), e.type === "keydown");
  }
  window.addEventListener("keydown", relay);
  window.addEventListener("keyup", relay);
})();
window.vsShowSubmit = function (p) {
  // vs-fix-11075 (DA F2): rebuild the panel on every terminal show — a second
  // death gets a fresh score line, empty #vs-result and an enabled button.
  // vs-fix-11083: symmetric removal lives on the run-start path — main.gd
  // _start_game() deletes #vs-submit through the JS bridge the moment a new
  // run begins, so a dead panel never sits over live gameplay.
  var stalePanel = document.getElementById("vs-submit");
  if (stalePanel) stalePanel.remove();
  var d = document.createElement("div");
  d.id = "vs-submit";
  d.style.cssText = "position:fixed;right:16px;top:56px;width:300px;max-height:80vh;overflow:auto;z-index:40;background:rgba(16,19,28,0.94);border:1px solid #2a3140;border-radius:8px;padding:12px;color:#d8d2c0;font:13px monospace";
  var h = document.createElement("div");
  h.textContent = "Score " + p.score + " — sign the ledger";
  h.style.cssText = "margin-bottom:8px";
  var inp = document.createElement("input");
  inp.id = "vs-name";
  inp.maxLength = 16;
  inp.placeholder = "Name (max 16)";
  inp.autocomplete = "off";
  inp.style.cssText = "width:100%;box-sizing:border-box;background:#10131c;border:1px solid #2a3140;color:#d8d2c0;padding:6px;margin-bottom:8px";
  var btn = document.createElement("button");
  btn.id = "vs-send";
  btn.textContent = "Submit score";
  btn.style.cssText = "width:100%;background:#8e2f35;border:0;color:#d8d2c0;padding:7px;cursor:pointer";
  var res = document.createElement("div");
  res.id = "vs-result";
  res.style.cssText = "margin-top:8px;white-space:pre-line";
  d.appendChild(h); d.appendChild(inp); d.appendChild(btn); d.appendChild(res);
  document.body.appendChild(d);
  function board() {
    return fetch("/api/highscores").then(function (r) { if (!r.ok) throw 0; return r.json(); })
      .then(function (j) {
        return (j.scores || []).map(function (s) {
          return "#" + s.rank + " " + s.name + " · " + s.score + " pts · Lv " + s.level + " · " + s.kills + " kills";
        }).join("\n");
      });
  }
  var ownerRun = (window.__vsSnapshot || {}).runId || "";
  btn.onclick = function () {
    // vs-fix-11075 (DA F2): a panel from a finished run must never POST after
    // a new run has taken over — compare the live snapshot's runId.
    var nowRun = (window.__vsSnapshot || {}).runId || "";
    if (ownerRun && nowRun && nowRun !== ownerRun) {
      res.textContent = "stale panel — this run was replaced";
      return;
    }
    btn.disabled = true;
    var name = (inp.value || "").trim().slice(0, 16) || "nameless";
    fetch("/api/highscores", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: name, score: p.score, time_survived: p.time_survived, kills: p.kills, level: p.level })
    }).then(function (r) { if (!r.ok) throw 0; return r.json(); })
      .then(function (j) {
        res.textContent = "Rank #" + j.rank;
        return board().then(function (b) {
          res.textContent += "\n\n" + (b || "No scores yet.");
        }).catch(function () { res.textContent += "\n(board offline)"; });
      })
      .catch(function () { res.textContent = "offline"; });
  };
};
</script>
