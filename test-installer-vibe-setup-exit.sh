#!/usr/bin/env bash
# The installer must not exit 0 when the workspace was not wired.
#
# Until 2026-10-27 every failure path in run_vibe_setup printed a warning and
# returned; main went on to print_success and the script exited 0, which the
# plugin bootstrap read as "installed and wired". The b243 "skipping
# reach-vibe setup" (B2) was one of these paths. This test runs the real
# run_vibe_setup + main tail from install.sh with a stub reachctl.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

FUNCS="$WORK/funcs.sh"
for fn in vibe_workspace_is_wireable resolve_vibe_workspace announce_vibe_surface run_vibe_setup run_bounded; do
  sed -n "/^${fn}() {/,/^}/p" "$ROOT_DIR/install.sh" >> "$FUNCS"
  grep -q "^${fn}() {" "$FUNCS" || fail "could not extract ${fn}"
done
cat >> "$FUNCS" <<'EOS'
print_step()  { echo "STEP $1"; }
print_info()  { echo "  $1"; }
print_ok()    { echo "  OK $1"; }
print_warn()  { echo "  WARN $1"; }
print_error() { echo "  ERROR $1" >&2; }
log_event()   { :; }
PUBLIC_INSTALL_URL="https://example.invalid/install.sh"
INSTALL_LOG="$WORK/install.log"
REACHABLE_TMP_ROOT="$WORK"
REACHABLE_INSTALLER_AGENT_SETUP=0
ENABLE_VIBE_CODING=true
VIBE_SURFACE_REASON="--vibe"
VIBE_AGENTS=()
VIBE_RUN_BASELINE=false
PY_BIN="$(command -v python3)"
REACHABLE_WIRE_MAX_TIME=900
REACHABLE_WIRE_BASELINE_MAX_TIME=14400
VIBE_SETUP_FAILED=""
main_tail() {
    run_vibe_setup
    if [[ -n "$VIBE_SETUP_FAILED" ]]; then
        print_error "REACHABLE is installed but this workspace was NOT wired: $VIBE_SETUP_FAILED"
        exit 1
    fi
    echo "SUCCESS"
}
EOS
# The main tail above must be the one in install.sh, not a retyped copy.
grep -q 'if \[\[ -n "\$VIBE_SETUP_FAILED" \]\]; then' "$ROOT_DIR/install.sh" || fail "install.sh main does not check VIBE_SETUP_FAILED"
grep -q 'was NOT wired: \$VIBE_SETUP_FAILED' "$ROOT_DIR/install.sh" || fail "install.sh main does not report the unwired workspace"

export HOME="$WORK/home"
mkdir -p "$HOME/.reachable/venv/bin" "$HOME/proj"
cat > "$HOME/.reachable/venv/bin/reachctl" <<'EOS'
#!/bin/sh
case "$*" in
  "vibe wire-workspace"*) exit "${WIRE_RC:-0}" ;;
esac
exit 0
EOS
chmod +x "$HOME/.reachable/venv/bin/reachctl"

# 1. wire-workspace fails -> installer exits 1 and says the workspace is not wired
set +e
WIRE_RC=1 VIBE_WORKSPACE="$HOME/proj" bash -c "source '$FUNCS'; VIBE_WORKSPACE='$HOME/proj'; main_tail" >"$WORK/out1" 2>&1
rc=$?
set -e
[[ $rc -eq 1 ]] || fail "wire-workspace failure: expected exit 1, got $rc: $(cat "$WORK/out1")"
grep -q 'was NOT wired' "$WORK/out1" || fail "no 'NOT wired' message: $(cat "$WORK/out1")"
grep -q 'SUCCESS' "$WORK/out1" && fail "printed success after a failed wiring"
echo "PASS wiring failure exits 1"

# 2. refused workspace (HOME) -> exit 1
set +e
VIBE_WORKSPACE="$HOME" bash -c "source '$FUNCS'; VIBE_WORKSPACE='$HOME'; main_tail" >"$WORK/out2" 2>&1
rc=$?
set -e
[[ $rc -eq 1 ]] || fail "refused workspace: expected exit 1, got $rc"
grep -q 'home directory or filesystem root' "$WORK/out2" || fail "refusal reason missing: $(cat "$WORK/out2")"
echo "PASS refused workspace exits 1"

# 3. wiring succeeds -> exit 0
bash -c "source '$FUNCS'; VIBE_WORKSPACE='$HOME/proj'; main_tail" >"$WORK/out3" 2>&1 || fail "successful wiring must exit 0: $(cat "$WORK/out3")"
grep -q 'SUCCESS' "$WORK/out3" || fail "success path did not reach print_success"
echo "PASS successful wiring exits 0"

# 4. --no-vibe: no wiring attempted, no failure recorded
bash -c "source '$FUNCS'; ENABLE_VIBE_CODING=false; VIBE_WORKSPACE='$HOME'; main_tail" >"$WORK/out4" 2>&1 || fail "--no-vibe must exit 0: $(cat "$WORK/out4")"
echo "PASS --no-vibe unaffected"
echo "OK"
