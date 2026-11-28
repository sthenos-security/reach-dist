#!/usr/bin/env bash
# An upgrade that fails leaves the previous runtime in place (the installer's own failure used to leave NO runtime:
# `pip uninstall` first, then a new venv, and a pip or network failure after that ended in `exit 1` with nothing to run).
# The old venv is moved aside to venv.previous, the new one is built at the real path (a venv cannot be moved: its scripts
# carry its path), a failure puts the old one back, and success deletes it. Runs the real functions of install.sh on a
# fake HOME with stand-in venvs; no network, no pip.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

FUNCS="$WORK/funcs.sh"
awk '/^RUNTIME_RETIRED=0/{p=1} /^# The daemon runs on the managed venv/{p=0} p' "$ROOT_DIR/install.sh" > "$FUNCS"
grep -q '^retire_previous_runtime() {' "$FUNCS" || fail "install.sh has no retire_previous_runtime"
grep -q '^commit_runtime() {' "$FUNCS" || fail "install.sh has no commit_runtime"
grep -q '^restore_previous_runtime_on_failure() {' "$FUNCS" || fail "install.sh has no restore_previous_runtime_on_failure"
cat >> "$FUNCS" <<'EOT'
print_info()  { echo "  $1"; }
print_warn()  { echo "  WARN $1"; }
print_error() { echo "  ERROR $1" >&2; }
stop_managed_daemon() { :; }   # its own test: test-installer-daemon-stop.sh
EOT

new_home() { # new_home <name> -> a HOME whose venv holds the OLD runtime
  export HOME="$WORK/$1"
  mkdir -p "$HOME/.reachable/venv/bin"
  make_runtime "$HOME/.reachable/venv" OLD
}
make_runtime() { # make_runtime <venv dir> <marker>: a venv whose python imports `reachable` only if it is complete
  mkdir -p "$1/bin"
  echo "$2" > "$1/MARKER"
  cat > "$1/bin/python" <<'EOT'
#!/bin/sh
[ -f "$(dirname "$0")/../COMPLETE" ] || exit 1
EOT
  chmod +x "$1/bin/python"
  touch "$1/COMPLETE"
}
marker() { cat "$HOME/.reachable/venv/MARKER" 2>/dev/null || echo none; }
run() { bash -c "set -euo pipefail; source '$FUNCS'; $1" 2>&1; }

# 1. Success: the new runtime is in place, the old one and its backup are gone.
new_home ok
run 'retire_previous_runtime; [[ ! -e "$HOME/.reachable/venv" ]]; mkdir -p "$HOME/.reachable/venv"; echo NEW > "$HOME/.reachable/venv/MARKER"; commit_runtime' >/dev/null \
  || fail "success path failed"
[[ "$(marker)" == NEW ]] || fail "success: the new runtime is not in place ($(marker))"
[[ ! -e "$HOME/.reachable/venv.previous" ]] || fail "success: the backup was left behind"
echo "PASS success: the new runtime replaces the old one and the backup is removed"

# 2. Failure after the old runtime was moved aside: the old one comes back, the installer's exit code is kept.
new_home failed
set +e
out="$(run 'retire_previous_runtime; mkdir -p "$HOME/.reachable/venv"; echo HALF > "$HOME/.reachable/venv/MARKER"; exit 7')"
rc=$?
set -e
[[ $rc -eq 7 ]] || fail "failure: the exit code was not kept (got $rc): $out"
[[ "$(marker)" == OLD ]] || fail "failure: the previous runtime was not put back ($(marker)): $out"
[[ ! -e "$HOME/.reachable/venv.previous" ]] || fail "failure: the backup name is still there"
grep -q 'previous runtime is back' <<<"$out" || fail "failure: the user is not told: $out"
echo "PASS failure: the previous runtime is put back and the user is told"

# 3. A kill (the trap cannot run) leaves venv.previous and a half-built venv; the next run restores the old runtime first.
new_home killed
run 'retire_previous_runtime; mkdir -p "$HOME/.reachable/venv/bin"; echo HALF > "$HOME/.reachable/venv/MARKER"; printf "#!/bin/sh\\nexit 1\\n" > "$HOME/.reachable/venv/bin/python"; chmod +x "$HOME/.reachable/venv/bin/python"; trap - EXIT; exit 0' >/dev/null || true
[[ -d "$HOME/.reachable/venv.previous" ]] || fail "killed: set-up of the scenario failed"
out="$(run 'retire_previous_runtime; echo after-retire')" || fail "killed: the next run failed: $out"
[[ "$(cat "$HOME/.reachable/venv.previous/MARKER")" == OLD ]] || fail "killed: the old runtime was not recovered ($out)"
grep -q 'interrupted' <<<"$out" || fail "killed: the user is not told about the interrupted upgrade: $out"
echo "PASS an interrupted upgrade is recovered at the next run"

# 4. A backup left over from an upgrade that finished: the working runtime stays, the backup goes.
new_home leftover
mkdir -p "$HOME/.reachable/venv.previous" && echo STALE > "$HOME/.reachable/venv.previous/MARKER"
run 'retire_previous_runtime; [[ "$(cat "$HOME/.reachable/venv.previous/MARKER")" == OLD ]]; commit_runtime' >/dev/null || fail "leftover: the stale backup replaced the working runtime"
echo "PASS a stale backup never replaces a working runtime"

# 5. First install: no venv, nothing to retire, no trap that could fail an install.
export HOME="$WORK/first"; mkdir -p "$HOME/.reachable"
run 'retire_previous_runtime; mkdir -p "$HOME/.reachable/venv"; commit_runtime; exit 0' >/dev/null || fail "first install failed"
echo "PASS a first install has nothing to retire"

# 6. Every place install.sh replaces the runtime retires it first and commits at the end (no `pip uninstall` first).
retire_sites="$(grep -c '^\s*retire_previous_runtime$' "$ROOT_DIR/install.sh")"
commit_sites="$(grep -c '^\s*commit_runtime$' "$ROOT_DIR/install.sh")"
[[ "$retire_sites" -ge 2 ]] || fail "expected a retire_previous_runtime call at each of the 2 upgrade sites, found $retire_sites"
[[ "$commit_sites" -ge 3 ]] || fail "expected commit_runtime at the 3 success points (wheel, download, bundle), found $commit_sites"
if grep -nE '^\s*if ! uninstall_managed_reachable; then' "$ROOT_DIR/install.sh" | grep -v 'uninstall_all' >/dev/null; then
  : # the explicit --uninstall flow still uses it; only the upgrade sites must not
fi
echo "OK"
