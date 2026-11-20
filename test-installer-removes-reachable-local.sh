#!/usr/bin/env bash
# install.sh removes reachable@reachable-local (reach-core design §16a rule 8,
# b286 #47). End state is read from the REAL claude CLI in a throwaway HOME:
# a seeded reachable-local plugin + marketplace are gone, reachable@other is
# kept. Needs `claude` on PATH; refuses (exit 1) without it, never skips.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_BIN="$(command -v claude)" || { echo "FAIL: claude CLI not on PATH"; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/reach-local-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home" CLAUDE_CONFIG_DIR="$WORK/home/.claude"
mkdir -p "$HOME"

seed_marketplace() {  # name plugin-version
    local root="$WORK/$1"
    mkdir -p "$root/.claude-plugin" "$root/plugins/reachable/.claude-plugin"
    printf '{"name":"%s","owner":{"name":"test"},"plugins":[{"name":"reachable","source":"./plugins/reachable","version":"%s"}]}\n' "$1" "$2" > "$root/.claude-plugin/marketplace.json"
    printf '{"name":"reachable","version":"%s"}\n' "$2" > "$root/plugins/reachable/.claude-plugin/plugin.json"
    "$CLAUDE_BIN" plugin marketplace add "$root" >/dev/null
    "$CLAUDE_BIN" plugin install "reachable@$1" --scope user >/dev/null
}
seed_marketplace reachable-local 1.0.0b230
seed_marketplace keep-me 1.0.0b286

ids() { "$CLAUDE_BIN" plugin list --json | python3 -c 'import json,sys; print(" ".join(sorted(p["id"] for p in json.load(sys.stdin))))'; }
markets() { "$CLAUDE_BIN" plugin marketplace list --json | python3 -c 'import json,sys; print(" ".join(sorted(m["name"] for m in json.load(sys.stdin))))'; }
[[ "$(ids)" == "reachable@keep-me reachable@reachable-local" ]] || { echo "FAIL: seeding: $(ids)"; exit 1; }

REACHABLE_INSTALLER_SOURCE_ONLY=1 source "$HERE/install.sh"
PY_BIN="$(command -v python3)"
out="$(remove_stale_claude_plugin 2>&1)"

fail=0
check() { if eval "$2"; then echo "  PASS  $1"; else echo "  FAIL  $1"; fail=1; fi; }
check "reachable-local plugin removed, the other kept" '[[ "$(ids)" == "reachable@keep-me" ]]'
check "reachable-local marketplace removed" '[[ "$(markets)" == "keep-me" ]]'
check "says what it removed" 'grep -q "Removed the old Reachable plugin reachable@reachable-local (user scope)" <<<"$out"'
second="$(remove_stale_claude_plugin 2>&1)"
check "second run changes nothing and prints nothing" '[[ -z "$second" && "$(ids)" == "reachable@keep-me" ]]'
[[ $fail -eq 0 ]] && echo "removes reachable-local: PASS" || { echo "removes reachable-local: FAIL"; printf '%s\n' "$out"; exit 1; }
