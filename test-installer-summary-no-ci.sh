#!/usr/bin/env bash
# The install summary does not detect CI.
#
# install.sh states that it detects no CI (the comment above
# ENABLE_VIBE_CODING; SINGLE-INSTALL-MODE: one detector, in the bootstrap).
# Until 2026-10-27 print_success read CI / GITHUB_ACTIONS anyway to pick its
# output form -- a second detector. This runs the real print_success with
# CI=true and checks it prints the same summary as without, and that the
# explicit REACHABLE_INSTALLER_SUMMARY=compact still gives the short form.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

FUNCS="$WORK/funcs.sh"
sed -n "/^print_success() {/,/^}/p" "$ROOT_DIR/install.sh" > "$FUNCS"
grep -q "^print_success() {" "$FUNCS" || fail "could not extract print_success"
cat >> "$FUNCS" <<'EOS'
GREEN="" BOLD="" NC=""
PUBLIC_INSTALL_URL="https://example.invalid/install.sh"
ENABLE_VIBE_CODING=true
VIBE_SURFACE_REASON="default"
VIBE_AGENTS=()
VIBE_UI_URL=""
PATH_CONFIG_STATUS="updated"
PATH_CONFIG_TARGET="$HOME/.bashrc"
UPDATE_MODE=false
CLEAN_DATA=false
BACKUP_DIR=""
VERSION="1.0.0b999"
INSTALL_LOG=""
EOS

summary() { # summary <env...>
  env "$@" bash -c "set -uo pipefail; source '$FUNCS'; print_success"
}

plain="$(summary CI= GITHUB_ACTIONS=)"
under_ci="$(summary CI=true GITHUB_ACTIONS=true)"
grep -q "Start Here" <<<"$plain" || fail "control: the full summary has no 'Start Here'"
[[ "$under_ci" == "$plain" ]] || fail "CI=true changed the summary (a second CI detector):
$(diff <(echo "$plain") <(echo "$under_ci") | head -8)"
echo "PASS CI does not change the summary"

compact="$(summary REACHABLE_INSTALLER_SUMMARY=compact)"
grep -q "Start Here" <<<"$compact" && fail "REACHABLE_INSTALLER_SUMMARY=compact did not give the short form"
echo "PASS the explicit compact form still works"
echo "OK"
