#!/usr/bin/env bash
# --clean removes ~/.reachable (keys, scan history, the install record) only after an explicit yes: asked on a
# terminal, or given as --yes. Without either it refuses, removes nothing, and says exactly what it would remove.
#
# History: 2026-11-28 local install review (I-9b): `--clean` ran `rm -rf "$HOME/.reachable"` with no question, from a
# curl | bash pipe, and left the agent hooks pointing at a runtime that was gone.
#
# This test runs the real handle_existing_install from install.sh against a fake HOME. Case 1 runs in a new session
# with no controlling terminal, so the real terminal check is what refuses.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v python3 >/dev/null || fail "python3 is needed to run a case with no controlling terminal"

seed_home() {
  rm -rf "${WORK:?}/home"
  mkdir -p "$WORK/home/.reachable/scans/app1" "$WORK/home/.reachable/venv/bin"
  echo "dummy" > "$WORK/home/.reachable/scans/app1/repo.db"
  echo "dummy" > "$WORK/home/.reachable/config.yaml"
}

# run_case <tty: real|yes|no> <answer: y|n|-> <installer args...>
run_case() {
  local tty="$1" answer="$2"; shift 2
  HOME="$WORK/home" TTY_MODE="$tty" ANSWER="$answer" python3 -c '
import subprocess, sys
sys.exit(subprocess.call(sys.argv[1:], start_new_session=True, stdin=subprocess.DEVNULL))
' "$BASH" -c '
    set -euo pipefail
    export REACHABLE_INSTALLER_SOURCE_ONLY=1
    installer="$1"; shift
    source "$installer" "$@"
    print_step()  { echo "STEP $1"; }
    print_ok()    { echo "OK $1"; }
    print_info()  { echo "  $1"; }
    print_warn()  { echo "WARN $1"; }
    print_error() { echo "ERROR $1"; }
    managed_reachable_version() { return 1; }   # no runtime answers: only the --clean block runs
    stop_managed_daemon() { echo "STOPPED daemon"; }
    case "$TTY_MODE" in
      real) ;;
      yes)  installer_has_tty() { return 0; }
            installer_ask_yes_no() { echo "ASKED: $1"; [[ "$ANSWER" == y ]]; } ;;
      no)   installer_has_tty() { return 1; } ;;
    esac
    WHEEL_VERSION=1.0.0b1
    INSTALL_LOG=""
    handle_existing_install
    echo "RETURNED"
  ' _ "$ROOT_DIR/install.sh" "$@" 2>&1
}

# 1. --clean, no terminal (real check, new session), no --yes: refused, exit 2, nothing removed, names what it removes.
seed_home
set +e; out="$(run_case real - --clean)"; rc=$?; set -e
[[ "$rc" == 2 ]] || fail "--clean with no terminal: expected exit 2, got $rc. Output: $out"
[[ -f "$WORK/home/.reachable/scans/app1/repo.db" ]] || fail "--clean with no terminal removed data. Output: $out"
grep -q 'STOPPED daemon' <<<"$out" && fail "--clean with no terminal stopped the daemon before any yes. Output: $out"
grep -q "$WORK/home/.reachable" <<<"$out" || fail "refusal does not name the folder it would remove. Output: $out"
grep -q 'scans' <<<"$out" || fail "refusal does not list what is inside (scans). Output: $out"
grep -q -- '--yes' <<<"$out" || fail "refusal does not name --yes. Output: $out"

# 2. --clean --yes, no terminal: removed without a question.
seed_home
set +e; out="$(run_case no - --clean --yes)"; rc=$?; set -e
[[ "$rc" == 0 ]] || fail "--clean --yes: expected exit 0, got $rc. Output: $out"
[[ ! -e "$WORK/home/.reachable/scans" ]] || fail "--clean --yes did not remove the data. Output: $out"
grep -q 'ASKED' <<<"$out" && fail "--clean --yes still asked. Output: $out"

# 3. --clean on a terminal, answer no: exit 1, nothing removed, the question listed what goes.
seed_home
set +e; out="$(run_case yes n --clean)"; rc=$?; set -e
[[ "$rc" == 1 ]] || fail "--clean answered no: expected exit 1, got $rc. Output: $out"
[[ -f "$WORK/home/.reachable/config.yaml" ]] || fail "--clean answered no removed data. Output: $out"
grep -q 'ASKED' <<<"$out" || fail "--clean on a terminal did not ask. Output: $out"
grep -q 'config.yaml' <<<"$out" || fail "the question does not list what is inside. Output: $out"

# 4. --clean on a terminal, answer yes: removed, then the install goes on.
seed_home
set +e; out="$(run_case yes y --clean)"; rc=$?; set -e
[[ "$rc" == 0 ]] || fail "--clean answered yes: expected exit 0, got $rc. Output: $out"
[[ ! -e "$WORK/home/.reachable/config.yaml" ]] || fail "--clean answered yes did not remove the data. Output: $out"
grep -q 'RETURNED' <<<"$out" || fail "--clean answered yes did not go on. Output: $out"

echo "PASS: --clean removes ~/.reachable only on an explicit yes"
