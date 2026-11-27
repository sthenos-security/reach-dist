#!/usr/bin/env bash
# The daemon is stopped before the managed runtime is removed or replaced.
#
# 2026-10-26 (Linux, b243): daemon pid 12423 survived two `rm -rf
# ~/.reachable/venv` rebuilds, its log stayed empty, and `vibe status` was
# served by a process whose runtime no longer existed. install.sh now calls
# stop_managed_daemon before every venv removal and before every
# "Removing previous installation". This test runs that function from
# install.sh against a stub reachctl, and checks every removal site in
# install.sh is preceded by the call -- a site added later without it is
# exactly the defect.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

FUNCS="$WORK/funcs.sh"
sed -n '/^stop_managed_daemon() {/,/^}/p' "$ROOT_DIR/install.sh" > "$FUNCS"
grep -q '^stop_managed_daemon() {' "$FUNCS" || fail "could not extract stop_managed_daemon"
cat >> "$FUNCS" <<'EOF'
print_info()  { echo "  $1"; }
print_warn()  { echo "  WARN $1"; }
print_error() { echo "  ERROR $1" >&2; }
EOF

export HOME="$WORK/home"
export STUB_LOG="$WORK/calls"
mkdir -p "$HOME/.reachable/venv/bin"
cat > "$HOME/.reachable/venv/bin/reachctl" <<'EOF'
#!/bin/sh
echo "reachctl $*" >> "$STUB_LOG"
case "$*" in
  --version) echo "reachctl 1.0.0-stub" ;;
  "vibe daemon stop") exit "${DAEMON_STOP_RC:-0}" ;;
esac
EOF
chmod +x "$HOME/.reachable/venv/bin/reachctl"

# 1. Runtime present: the daemon is asked to stop through reachctl.
bash -c "source '$FUNCS'; stop_managed_daemon" >/dev/null
grep -q '^reachctl vibe daemon stop$' "$STUB_LOG" || fail "stop_managed_daemon did not call 'reachctl vibe daemon stop'"
echo "PASS daemon stopped through reachctl"

# 2. The daemon refuses to stop: the installer must NOT go on to replace the
#    runtime under it.
: > "$STUB_LOG"
set +e
DAEMON_STOP_RC=3 bash -c "source '$FUNCS'; stop_managed_daemon; echo reached-after-stop" >"$WORK/out" 2>&1
rc=$?
set -e
[[ $rc -eq 1 ]] || fail "daemon that will not stop: expected exit 1, got $rc"
grep -q 'reached-after-stop' "$WORK/out" && fail "installer continued past a daemon it could not stop"
grep -q 'refusing to replace the runtime' "$WORK/out" || fail "refusal not explained: $(cat "$WORK/out")"
echo "PASS a daemon that will not stop halts the installer"

# 3. No usable runtime (a half-installed venv): nothing to stop through, say so,
#    continue -- the rebuild IS the repair for that state.
rm -rf "$HOME/.reachable/venv"
out="$(bash -c "source '$FUNCS'; stop_managed_daemon; echo reached-after-stop" 2>&1)"
grep -q 'reached-after-stop' <<<"$out" || fail "no-runtime case must not abort: $out"
grep -q 'managed runtime cannot run' <<<"$out" || fail "no-runtime case must say so: $out"
echo "PASS no runtime: warns and continues"

# 5. P12 (b289 -> b290): an INSTALLED runtime whose `vibe daemon stop` crashes with
#    PermissionError unless XDG_RUNTIME_DIR names a directory it accepts (a host with no
#    XDG_RUNTIME_DIR and no /run/user/<uid>; reachctl keeps TMPDIR under ~/.reachable, so setting
#    TMPDIR cannot help). The installer must give it /tmp/runtime-<uid> (0700), or a b289 user can
#    never upgrade (run 46043309009). The stub fails exactly like b289 does, and ignores TMPDIR.
mkdir -p "$HOME/.reachable/venv/bin"
cat > "$HOME/.reachable/venv/bin/reachctl" <<'EOF2'
#!/bin/sh
echo "reachctl $* XDG=${XDG_RUNTIME_DIR:-unset}" >> "$STUB_LOG"
case "$*" in
  --version) echo "reachctl 1.0.0b289-stub" ;;
  "vibe daemon stop")
    if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
      echo "PermissionError: runtime directory $HOME/.reachable/tmp/runtime-1002 is below $HOME/.reachable, writable by another user; set XDG_RUNTIME_DIR instead" >&2; exit 1
    fi
    [ -d "$XDG_RUNTIME_DIR" ] && [ "$(stat -c %a "$XDG_RUNTIME_DIR" 2>/dev/null || stat -f %Lp "$XDG_RUNTIME_DIR")" = 700 ] || exit 1
    exit 0 ;;
esac
EOF2
chmod +x "$HOME/.reachable/venv/bin/reachctl"
: > "$STUB_LOG"
want="/tmp/runtime-$(id -u)"
rm -rf "$want"
if [[ -d "/run/user/$(id -u)" ]]; then
  echo "SKIP 5: this host has /run/user/$(id -u), so the installer leaves XDG_RUNTIME_DIR alone"
else
  out="$(env -u XDG_RUNTIME_DIR TMPDIR="$HOME/.reachable/tmp" bash -c "source '$FUNCS'; stop_managed_daemon; echo reached-after-stop" 2>&1)" \
    || fail "b289-style stop crashed the installer: $out"
  grep -q 'reached-after-stop' <<<"$out" || fail "installer did not continue after stopping a b289 runtime: $out"
  grep -q "^reachctl vibe daemon stop XDG=$want\$" "$STUB_LOG" || fail "the stop did not run with XDG_RUNTIME_DIR=$want: $(cat "$STUB_LOG")"
  echo "PASS a runtime that needs XDG_RUNTIME_DIR is stopped with $want (0700)"
fi
# A host that already has XDG_RUNTIME_DIR keeps it.
: > "$STUB_LOG"
mkdir -p "$WORK/xdg" && chmod 0700 "$WORK/xdg"
XDG_RUNTIME_DIR="$WORK/xdg" bash -c "source '$FUNCS'; stop_managed_daemon" >/dev/null 2>&1 || fail "stop failed with a host-provided XDG_RUNTIME_DIR"
grep -q "XDG=$WORK/xdg\$" "$STUB_LOG" || fail "the installer replaced the host's XDG_RUNTIME_DIR: $(cat "$STUB_LOG")"
echo "PASS a host-provided XDG_RUNTIME_DIR is kept"

# 4. Every removal site in install.sh is immediately preceded by the stop call.
sites=0
while IFS= read -r line; do
  sites=$((sites+1))
  n="${line%%:*}"
  prev="$(sed -n "$((n-1))p" "$ROOT_DIR/install.sh")"
  [[ "$prev" =~ ^[[:space:]]*stop_managed_daemon$ ]] \
    || fail "install.sh:$n removes the runtime without stop_managed_daemon on the line before: $line"
done < <(grep -n -E '^\s*(rm -rf "\$HOME/\.reachable(/venv)?"|if ! uninstall_managed_reachable; then)$' "$ROOT_DIR/install.sh")
[[ $sites -ge 4 ]] || fail "expected at least 4 runtime-removal sites in install.sh, found $sites"
echo "PASS all $sites runtime-removal sites stop the daemon first"
echo "OK"
