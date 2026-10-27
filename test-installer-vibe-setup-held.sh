#!/usr/bin/env bash
# On the plugin path (REACHABLE_INSTALLER_AGENT_SETUP=1) a guard hold names
# its findings instead of "reach-vibe setup failed (see the install log)".
#
# reach-core dd8bdc38: wire-workspace runs the agent-config guard first and
# exits 3 with `held: <agent> <code> <path>` lines. With wire-once, install.sh's
# wiring is the only one on the plugin path, so the user sees the hold here or
# nowhere. This runs the real run_vibe_setup with a stub reachctl.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

FUNCS="$WORK/funcs.sh"
for fn in vibe_workspace_is_wireable resolve_vibe_workspace announce_vibe_surface run_vibe_setup; do
  sed -n "/^${fn}() {/,/^}/p" "$ROOT_DIR/install.sh" >> "$FUNCS"
  grep -q "^${fn}() {" "$FUNCS" || fail "could not extract ${fn}"
done
cat >> "$FUNCS" <<'EOS'
print_step()  { echo "STEP $1"; }
print_info()  { echo "  $1"; }
print_ok()    { echo "  OK $1"; }
print_warn()  { echo "  WARN $1"; }
print_error() { echo "  ERROR $1"; }
log_event()   { :; }
PUBLIC_INSTALL_URL="https://example.invalid/install.sh"
REACHABLE_INSTALLER_AGENT_SETUP=1
ENABLE_VIBE_CODING=true
VIBE_SURFACE_REASON="--vibe"
VIBE_AGENTS=(claude-code)
VIBE_RUN_BASELINE=false
VIBE_SETUP_FAILED=""
EOS

export HOME="$WORK/home"
mkdir -p "$HOME/.reachable/venv/bin" "$HOME/proj"
cat > "$HOME/.reachable/venv/bin/reachctl" <<'EOS'
#!/bin/sh
case "$*" in
  "vibe wire-workspace"*)
    echo "→ agent-config guard (stage 0)"
    echo "  held: claude_code hook_exec_payload .claude/settings.json"
    exit 3 ;;
esac
exit 0
EOS
chmod +x "$HOME/.reachable/venv/bin/reachctl"

set +e
out="$(bash -c "source '$FUNCS'; INSTALL_LOG='$WORK/install.log'; REACHABLE_TMP_ROOT='$WORK'; VIBE_WORKSPACE='$HOME/proj'; run_vibe_setup; echo \"VIBE_SETUP_FAILED=\$VIBE_SETUP_FAILED\"" 2>&1)"
set -e
grep -q 'held: claude_code hook_exec_payload .claude/settings.json' <<<"$out" \
  || fail "the held: finding did not reach the output:
$out"
grep -q 'VIBE_SETUP_FAILED=the agent-config guard held' <<<"$out" \
  || fail "the hold was not recorded as the reason the workspace was not wired:
$out"
grep -q 'wire-anyway' <<<"$out" && fail "output names the bypass flag (AGENT-CONFIG-GUARD §0)"
echo "PASS a guard hold names its finding on the plugin path"
echo "OK"
