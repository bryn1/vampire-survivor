#!/usr/bin/env bash
# Live API smoke for the Hollow Dawn server: 20 cases against a self-started
# server on its own port with a throwaway /tmp DB. Kills the exact PID on exit.
# Run from anywhere: bash scripts/smoke.sh   (vendored per DA finding F3, MC 11075)
set -u
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 1
PORT="${VS_SMOKE_PORT:-8912}"
DB="${TMPDIR:-/tmp}/vs-smoke-$$.db"
B=http://127.0.0.1:$PORT
PASS=0; FAIL=0

req() { # req <desc> <expected_status> <expected_substring> <curl args...>
  local desc="$1" want="$2" wantbody="$3"; shift 3
  local raw code
  raw=$(curl -s --max-time 5 -w '\n%{http_code}' "$@")
  body=${raw%$'\n'*}; code=${raw##*$'\n'}
  local ok=1 why=""
  [ "$code" = "$want" ] || { ok=0; why="status $code != $want"; }
  if [ -n "$wantbody" ] && ! printf '%s' "$body" | grep -qF -- "$wantbody"; then
    ok=0; why="$why body lacks [$wantbody]"
  fi
  echo "CASE: $desc"
  echo "  REQ : curl $*"
  echo "  RESP: $code $body"
  if [ $ok = 1 ]; then echo "  OK"; PASS=$((PASS+1));
  else echo "  FAIL: $why"; FAIL=$((FAIL+1)); fi
}

echo "== Hollow Dawn server smoke $(date -u +%FT%TZ) port=$PORT db=$DB"
rm -f "$DB" "$DB"-wal "$DB"-shm
VS_PORT=$PORT VS_DB=$DB python3 server/server.py > "${TMPDIR:-/tmp}/vs-smoke-$$.log" 2>&1 &
SRV=$!
trap 'kill -0 $SRV 2>/dev/null && kill $SRV 2>/dev/null; wait $SRV 2>/dev/null; rm -f "$DB" "$DB"-wal "$DB"-shm "${TMPDIR:-/tmp}/vs-smoke-$$.log"' EXIT
for i in $(seq 1 50); do
  curl -s -o /dev/null "$B/api/health" && break
  sleep 0.1
done
echo "-- server log:"; cat "${TMPDIR:-/tmp}/vs-smoke-$$.log"; echo

req "1 health" 200 '{"status":"ok"}' "$B/api/health"
req "2 valid POST -> 201 + rank" 201 '"rank":1' \
  -X POST -H 'Content-Type: application/json' \
  -d '{"name":"Elin","score":1500,"time_survived":312.5,"kills":87,"level":9}' "$B/api/highscores"
req "3 name too long -> 422" 422 '"name"' \
  -X POST -d '{"name":"01234567890123456789","score":10,"time_survived":1,"kills":1,"level":1}' "$B/api/highscores"
req "4 name empty -> 422" 422 '"name"' \
  -X POST -d '{"name":"   ","score":10,"time_survived":1,"kills":1,"level":1}' "$B/api/highscores"
req "5 score float -> 422" 422 '"score"' \
  -X POST -d '{"name":"A","score":10.5,"time_survived":1,"kills":1,"level":1}' "$B/api/highscores"
req "6 score over max -> 422" 422 '"score"' \
  -X POST -d '{"name":"A","score":1000000000,"time_survived":1,"kills":1,"level":1}' "$B/api/highscores"
req "7 kills negative -> 422" 422 '"kills"' \
  -X POST -d '{"name":"A","score":10,"time_survived":1,"kills":-1,"level":1}' "$B/api/highscores"
req "8 level 0 -> 422" 422 '"level"' \
  -X POST -d '{"name":"A","score":10,"time_survived":1,"kills":1,"level":0}' "$B/api/highscores"
req "9 bool type -> 422" 422 '"VALIDATION"' \
  -X POST -d '{"name":"A","score":true,"time_survived":1,"kills":1,"level":1}' "$B/api/highscores"
req "10 malformed JSON -> 400" 400 '"BAD_JSON"' \
  -X POST -d '{nope' "$B/api/highscores"
req "11 second insert higher score -> rank 1" 201 '"rank":1' \
  -X POST -d '{"name":"Karl","score":999999,"time_survived":600,"kills":500,"level":20}' "$B/api/highscores"
req "12 GET board top-10 ranked, score DESC" 200 '"rank":1,"name":"Karl","score":999999' "$B/api/highscores"
req "13 board contains first insert at rank 2" 200 '"rank":2,"name":"Elin","score":1500' "$B/api/highscores"
req "14 unknown /api/x -> 404 NOT_FOUND" 404 '"NOT_FOUND"' "$B/api/x"
req "15 POST /api/health -> 405" 405 '"METHOD_NOT_ALLOWED"' -X POST "$B/api/health"
req "16 DELETE /api/highscores -> 405" 405 '"METHOD_NOT_ALLOWED"' -X DELETE "$B/api/highscores"
req "17 traversal /../../etc/passwd -> 404, no leak" 404 '"NOT_FOUND"' --path-as-is "$B/../../etc/passwd"
req "18 traversal encoded -> 404" 404 '"NOT_FOUND"' --path-as-is "$B/%2e%2e/%2e%2e/etc/passwd"
# leak assertion: the traversal response must carry no /etc/passwd content
echo "CASE: 19 leak check on traversal response"
echo "  RESP: $body"
if printf '%s' "$body" | grep -q 'root:'; then
  echo "  FAIL: passwd content leaked"; FAIL=$((FAIL+1));
else echo "  OK: no root: line in body"; PASS=$((PASS+1)); fi
req "20 GET / serves the exported index.html" 200 '<!DOCTYPE html>' "$B/"

echo; echo "RESULT: PASS=$PASS FAIL=$FAIL"
if [ $FAIL -eq 0 ]; then echo "VERIFY_EXIT=0"; exit 0
else echo "VERIFY_EXIT=1"; exit 1; fi
