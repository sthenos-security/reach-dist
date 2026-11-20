#!/usr/bin/env bash
# The installer's summary, as an agent's setup shows it in chat, names only the
# next command and links the page at Results (reach-core design §16a rule 4,
# b286 #6/#22). b285 ended with "Next: run reachable: doctor in the agent." and
# a "Dashboard:" line. Runs the real print_success from install.sh.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
for fn in results_page_url print_success; do
    src="$(awk -v f="$fn() {" '$0 == f {on=1} on {print} on && $0 == "}" {exit}' "$HERE/install.sh")"
    eval "$src"
    declare -F "$fn" >/dev/null || { echo "FAIL: $fn not found in install.sh"; exit 1; }
done

PUBLIC_INSTALL_URL="https://sthenosec.com/download/install.sh"
ENABLE_VIBE_CODING=true
VIBE_SURFACE_REASON="default"
VIBE_AGENTS=(claude_code)
PATH_CONFIG_STATUS=updated
PATH_CONFIG_TARGET="$HOME/.zshrc"
REACHABLE_INSTALLER_SUMMARY=auto
UPDATE_MODE=false
CLEAN_DATA=false
GREEN="" NC="" BOLD=""
INSTALL_LOG="/tmp/install.log"
BACKUP_DIR=""
VERSION="1.0.0b999"
VIBE_UI_URL="http://127.0.0.1:8765/?workspace=%2Fwork%2Fapp"

out="$(print_success)"
fail=0
check() { if eval "$2"; then echo "  PASS  $1"; else echo "  FAIL  $1"; fail=1; fi; }
last="$(printf '%s\n' "$out" | awk 'NF {line = $0} END {print line}')"
check "last line is the Next line" '[[ "$last" == "  Next: say \`reachable: settings\`" ]]'
check "page link opens Results" 'grep -qxF "  Reachable page: http://127.0.0.1:8765/results?workspace=%2Fwork%2Fapp" <<<"$out"'
check "no doctor" '! grep -qi doctor <<<"$out"'
check "no dashboard" '! grep -qi dashboard <<<"$out"'
[[ $fail -eq 0 ]] && echo "agent next line: PASS" || { echo "agent next line: FAIL"; printf '%s\n' "$out"; exit 1; }
