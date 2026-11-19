#!/usr/bin/env bash
# install.sh download_with_retries: bounded attempts with a delay between them,
# recovery from transient 5xx, exhaustion, and no retry on a permanent refusal.
#
# 2026-11-19, POSTRELEASE-TEST-UPGRADE goose lane: a key-list signature
# download answered HTTP 500 and the install aborted. This proves what the
# retry policy does against a local server that counts every request.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'kill "$SERVER_PID" 2>/dev/null || true; rm -rf "$WORK"' EXIT

cat >"$WORK/server.py" <<'PY'
import http.server, sys, collections
hits = collections.Counter()
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass
    def do_GET(self):
        hits[self.path] += 1
        if self.path == "/hits":
            body = "\n".join(f"{k} {v}" for k, v in hits.items()).encode()
            self.send_response(200); self.end_headers(); self.wfile.write(body); return
        if self.path == "/flaky" and hits[self.path] <= 2:
            self.send_response(500); self.end_headers(); return
        if self.path == "/down":
            self.send_response(500); self.end_headers(); return
        if self.path == "/gone":
            self.send_response(404); self.end_headers(); return
        if self.path == "/flaky":
            self.send_response(200); self.end_headers(); self.wfile.write(b"ok"); return
        raise ValueError(f"unhandled test path {self.path}")
s = http.server.HTTPServer(("127.0.0.1", 0), H)
print(s.server_address[1], flush=True)
s.serve_forever()
PY
python3 "$WORK/server.py" >"$WORK/port" &
SERVER_PID=$!
for _ in $(seq 50); do [[ -s "$WORK/port" ]] && break; sleep 0.1; done
PORT="$(head -1 "$WORK/port")"
BASE="http://127.0.0.1:$PORT"

# Load only the function under test, with the config it reads.
print_info() { :; }
REACHABLE_DOWNLOAD_RETRIES=3
REACHABLE_DOWNLOAD_RETRY_DELAY=1
REACHABLE_DOWNLOAD_CONNECT_TIMEOUT=5
REACHABLE_DOWNLOAD_MAX_TIME=30
unset RELEASES_API_TOKEN
for fn in _download_once download_with_retries; do
    src="$(awk -v f="$fn() {" '$0 == f {on=1} on {print} on && $0 == "}" {exit}' "$HERE/install.sh")"
    eval "$src"
    declare -F "$fn" >/dev/null || { echo "FAIL: $fn not found in install.sh"; exit 1; }
done

hits() { curl -fsS "$BASE/hits" | awk -v p="$1" '$1 == p {print $2}'; }
fail=0
check() { if eval "$2"; then echo "  PASS  $1"; else echo "  FAIL  $1 ($3)"; fail=1; fi; }

t0=$SECONDS
set +e; download_with_retries "flaky" "$BASE/flaky" "$WORK/flaky.out" >/dev/null 2>&1; rc=$?; set -e
dt=$((SECONDS - t0))
check "recovers from two 500s" '[[ $rc -eq 0 && "$(cat "$WORK/flaky.out")" == ok ]]' "rc=$rc"
check "recovery took 3 requests" '[[ "$(hits /flaky)" == 3 ]]' "hits=$(hits /flaky)"
check "waited between attempts (1+2)" '[[ $dt -ge 3 ]]' "elapsed ${dt}s"

t0=$SECONDS
set +e; download_with_retries "down" "$BASE/down" "$WORK/down.out" >/dev/null 2>&1; rc=$?; set -e
dt=$((SECONDS - t0))
check "a server that stays at 500 fails" '[[ $rc -ne 0 && ! -e "$WORK/down.out" ]]' "rc=$rc"
check "exhaustion is 1 + RETRIES requests" '[[ "$(hits /down)" == 4 ]]' "hits=$(hits /down)"
check "exhaustion waited the doubling delays (1+2+4)" '[[ $dt -ge 7 ]]' "elapsed ${dt}s"
check "no partial file left" '[[ -z "$(ls "$WORK" | grep -F .part. || true)" ]]' "$(ls "$WORK")"

set +e; download_with_retries "gone" "$BASE/gone" "$WORK/gone.out" >/dev/null 2>&1; rc=$?; set -e
check "a 404 fails" '[[ $rc -ne 0 ]]' "rc=$rc"
check "a 404 is not retried" '[[ "$(hits /gone)" == 1 ]]' "hits=$(hits /gone)"

[[ $fail -eq 0 ]] && echo "download retries: PASS" || { echo "download retries: FAIL"; exit 1; }
