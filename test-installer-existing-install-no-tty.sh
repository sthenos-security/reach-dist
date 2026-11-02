#!/usr/bin/env bash
# An existing install, no --update/--clean, and no terminal: install.sh must
# refuse by name and change nothing. Until 2026-11-02 handle_existing_install
# read the answer from /dev/tty unconditionally and bash died on
# "/dev/tty: No such device or address" (reach-core G24 run 41470868277 and
# G15 run 41484582820, both CI hosts with no terminal).
#
# Runs install.sh's own handle_existing_install with no controlling terminal
# (a new session via python's start_new_session), stdin from /dev/null.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${INSTALLER:-$ROOT_DIR/install.sh}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

sed -n '/^handle_existing_install() {/,/^}/p' "$INSTALLER" > "$WORK/func.sh"
[[ -s "$WORK/func.sh" ]] || fail "could not extract handle_existing_install from install.sh"

mkdir -p "$WORK/home/.reachable"
echo keep > "$WORK/home/.reachable/marker"
cat > "$WORK/run.sh" <<SH
set -uo pipefail
print_step() { echo "STEP \$*"; }
print_info() { echo "INFO \$*"; }
print_warn() { echo "WARN \$*"; }
print_error() { echo "ERROR \$*"; }
print_ok() { echo "OK \$*"; }
stop_managed_daemon() { echo "DAEMON-STOPPED"; }
managed_reachable_version() { echo 1.0.0b258; }
BOLD= NC= YELLOW=
WHEEL_VERSION=1.0.0b260 UPDATE_MODE=false CLEAN_DATA=false INSTALL_ONLY=false
source "$WORK/func.sh"
handle_existing_install
echo "REACHED-AFTER rc=0 UPDATE_MODE=\$UPDATE_MODE"
SH

set +e
out="$(HOME="$WORK/home" python3 -c '
import subprocess, sys
done = subprocess.run(["bash", sys.argv[1]], stdin=subprocess.DEVNULL, capture_output=True,
                      text=True, start_new_session=True, timeout=30)
sys.stdout.write(done.stdout + done.stderr)
sys.exit(done.returncode)' "$WORK/run.sh")"
rc=$?
set -e

[[ $rc -eq 2 ]] || fail "expected exit 2 with no terminal, got $rc: $out"
grep -q "ERROR REACHABLE v1.0.0b258 is already installed and there is no terminal to ask." <<<"$out" \
    || fail "the refusal does not say why: $out"
grep -q "Pass --update to upgrade it (keeps data) or --clean to reinstall. Nothing was changed." <<<"$out" \
    || fail "the refusal does not name --update / --clean: $out"
grep -q "/dev/tty" <<<"$out" && fail "bash's own /dev/tty error leaked instead of the refusal: $out"
grep -q "REACHED-AFTER\|DAEMON-STOPPED" <<<"$out" && fail "the installer carried on: $out"
[[ "$(cat "$WORK/home/.reachable/marker")" == keep ]] || fail "the existing install was changed"
echo "PASS: no terminal, existing install: refused by name, nothing changed"
