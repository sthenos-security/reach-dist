#!/usr/bin/env bash
# doctor, selftest and wire-workspace are bounded, and a failed selftest
# fails the install.
#
# Until 2026-10-27 verify_installation ran `reachctl doctor --full` and
# `reachctl selftest` with no limit, and a failed selftest printed
# "Selftest failed (non-fatal)" and the install went on to report success.
# run_vibe_setup ran `reachctl vibe wire-workspace` with no limit either.
# This runs the real functions from install.sh with a stub reachctl; each
# case has a watchdog, so a function that does not bound its command fails
# the test instead of hanging it.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

FUNCS="$WORK/funcs.sh"
for fn in verify_installation vibe_workspace_is_wireable resolve_vibe_workspace announce_vibe_surface run_vibe_setup; do
  sed -n "/^${fn}() {/,/^}/p" "$ROOT_DIR/install.sh" >> "$FUNCS"
  grep -q "^${fn}() {" "$FUNCS" || fail "could not extract ${fn}"
done
# Present only once the fix is in.
sed -n "/^run_bounded() {/,/^}/p" "$ROOT_DIR/install.sh" >> "$FUNCS"
cat >> "$FUNCS" <<'EOS'
print_header() { echo "== $1"; }
print_step()   { echo "STEP $1"; }
print_info()   { echo "  $1"; }
print_ok()     { echo "  OK $1"; }
print_warn()   { echo "  WARN $1"; }
print_error()  { echo "  ERROR $1" >&2; }
log_event()    { :; }
bundle_mode_enabled() { return 1; }
BOLD="" NC=""
PY_BIN="$(command -v python3)"
PUBLIC_INSTALL_URL="https://example.invalid/install.sh"
INSTALL_LOG=""
REACHABLE_TMP_ROOT="$HOME/.reachable/tmp"
ENABLE_VIBE_CODING=true
VIBE_SURFACE_REASON="--vibe"
VIBE_AGENTS=()
VIBE_RUN_BASELINE=false
VIBE_SETUP_FAILED=""
VIBE_UI_URL=""
REACHABLE_DOCTOR_MAX_TIME="${REACHABLE_DOCTOR_MAX_TIME:-600}"
REACHABLE_SELFTEST_MAX_TIME="${REACHABLE_SELFTEST_MAX_TIME:-300}"
REACHABLE_WIRE_MAX_TIME="${REACHABLE_WIRE_MAX_TIME:-900}"
REACHABLE_WIRE_BASELINE_MAX_TIME="${REACHABLE_WIRE_BASELINE_MAX_TIME:-14400}"
EOS

export HOME="$WORK/home"
mkdir -p "$HOME/.reachable/venv/bin" "$HOME/.reachable/tmp" "$HOME/proj"
cat > "$HOME/.reachable/venv/bin/reachctl" <<'EOS'
#!/bin/sh
case "$*" in
  "doctor --full")
    [ "${DOCTOR_MODE:-ok}" = hang ] && sleep 60
    echo "doctor ok"; exit 0 ;;
  selftest*)
    if [ "${SELFTEST_MODE:-ok}" = fail ]; then echo "selftest: 2 checks failed"; exit 1; fi
    echo "selftest ok"; exit 0 ;;
  "vibe wire-workspace"*)
    [ "${WIRE_MODE:-ok}" = hang ] && sleep 60
    exit 0 ;;
  "vibe ui"*) echo "http://127.0.0.1:1/"; exit 0 ;;
  version|--version) echo "REACHABLE 1.0.0b999"; exit 0 ;;
esac
exit 0
EOS
chmod +x "$HOME/.reachable/venv/bin/reachctl"

# run_case <name> <seconds> <env...> -- <shell snippet>; sets RC, prints output to $WORK/<name>.out
run_case() {
  local name="$1" limit="$2"
  shift 2
  local -a envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  env "${envs[@]+"${envs[@]}"}" bash -c "set -uo pipefail; source '$FUNCS'; $1" > "$WORK/$name.out" 2>&1 &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if (( waited >= limit )); then
      kill -9 "$pid" 2>/dev/null || true
      pkill -f "sleep 60" 2>/dev/null || true
      fail "$name: still running after ${limit}s -- the command is not bounded"
    fi
    sleep 1
    waited=$((waited + 1))
  done
  set +e
  wait "$pid"
  RC=$?
  set -e
}

# 1. selftest failure is fatal (both output modes)
for setup in 0 1; do
  run_case "selftest-fail-$setup" 60 SELFTEST_MODE=fail REACHABLE_INSTALLER_AGENT_SETUP=$setup -- 'verify_installation'
  [[ $RC -eq 1 ]] || fail "selftest failed (agent setup=$setup) but verify_installation exited $RC: $(tail -3 "$WORK/selftest-fail-$setup.out")"
  grep -q "selftest did not pass" "$WORK/selftest-fail-$setup.out" \
    || fail "selftest failure (agent setup=$setup) not named: $(tail -3 "$WORK/selftest-fail-$setup.out")"
  grep -q "non-fatal" "$WORK/selftest-fail-$setup.out" && fail "selftest failure still called non-fatal"
done
echo "PASS a failed selftest fails the install"

# 2. a hung doctor is stopped at its limit (both output modes)
for setup in 0 1; do
  run_case "doctor-hang-$setup" 20 DOCTOR_MODE=hang REACHABLE_DOCTOR_MAX_TIME=2 REACHABLE_INSTALLER_AGENT_SETUP=$setup -- 'verify_installation'
  [[ $RC -ne 0 ]] || fail "a doctor that hit its limit must fail verification (agent setup=$setup)"
done
grep -q "timed out after 2 s" "$WORK/doctor-hang-0.out" \
  || fail "the doctor timeout is not named: $(tail -3 "$WORK/doctor-hang-0.out")"
echo "PASS doctor is bounded"

# 3. a hung wire-workspace is stopped and reported as not wired
run_case "wire-hang" 20 WIRE_MODE=hang REACHABLE_WIRE_MAX_TIME=2 REACHABLE_INSTALLER_AGENT_SETUP=1 -- \
  "VIBE_WORKSPACE='$HOME/proj'; run_vibe_setup; echo \"FAILED=[\$VIBE_SETUP_FAILED]\""
grep -q "FAILED=\[reachctl vibe wire-workspace" "$WORK/wire-hang.out" \
  || fail "a wire-workspace that hit its limit must be recorded as not wired: $(tail -4 "$WORK/wire-hang.out")"
echo "PASS wire-workspace is bounded"

# 4. control: everything healthy -> verify passes
run_case "healthy" 60 REACHABLE_INSTALLER_AGENT_SETUP=1 -- 'verify_installation'
[[ $RC -eq 0 ]] || fail "a healthy runtime failed verification: $(tail -5 "$WORK/healthy.out")"
echo "PASS healthy runtime verifies"
echo "OK"
