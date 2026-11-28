#!/usr/bin/env bash
# An upgrade never depends on the code it replaces: the running daemon is stopped at the operating-system level
# (pid file, identity check, SIGTERM, wait, SIGKILL), never by asking the installed `reachctl` to stop itself.
#
# History: 2026-10-26 (Linux, b243) a daemon survived two venv rebuilds; install.sh then stopped it before every
# removal. 2026-11-27 (run 46043309009, G15) the b289 `reachctl vibe daemon stop` crashed on a Linux user with no
# runtime folder, so the installer refused to continue and that user could never leave b289. The installer now
# signals the process itself (the reference is dpkg's start-stop-daemon: --pidfile, an identity check, --retry
# TERM/10/KILL/5). This test runs the real functions from install.sh against REAL processes under the installer's own
# strict mode, and a stand-in `reachctl` that fails and logs if it is ever called.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
# The stand-in daemons are started inside $(...) subshells, so their pids are recorded in a FILE: an array would be lost
# with the subshell and a failing test would leak the processes (found 2026-11-28: one survived a failed run).
PIDS_FILE="$WORK/started-pids"
: > "$PIDS_FILE"
cleanup() {
  local p
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    kill -KILL -- "-$p" 2>/dev/null || kill -KILL "$p" 2>/dev/null || true
  done < "$PIDS_FILE"
  rm -rf "$WORK"
}
trap cleanup EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

FUNCS="$WORK/funcs.sh"
awk '/^managed_daemon_pidfiles\(\) \{/{p=1} /^run_pip_with_retries\(\) \{/{p=0} p' "$ROOT_DIR/install.sh" > "$FUNCS"
grep -q '^stop_managed_daemon() {' "$FUNCS" || fail "could not extract the stop functions from install.sh"
cat >> "$FUNCS" <<'EOF'
print_info()  { echo "  $1"; }
print_warn()  { echo "  WARN $1"; }
print_error() { echo "  ERROR $1" >&2; }
EOF
command -v python3 >/dev/null || fail "python3 is needed to start the stand-in daemons in new process groups"

export HOME="$WORK/home"
export STUB_LOG="$WORK/reachctl-calls"
export XDG_RUNTIME_DIR="$WORK/xdg"
BIN="$HOME/.reachable/venv/bin"
mkdir -p "$BIN" "$XDG_RUNTIME_DIR/reach-vibe"
: > "$STUB_LOG"
# The installed runtime: any call to it is a defect now.
cat > "$BIN/reachctl" <<'EOF'
#!/bin/sh
echo "reachctl $*" >> "$STUB_LOG"
echo "PermissionError: the old runtime must never be asked to do anything" >&2
exit 1
EOF
chmod +x "$BIN/reachctl"

# A stand-in daemon: a real process under the managed venv path, leading its own process group, as the daemon does.
# mode term: exits on SIGTERM. stubborn: ignores SIGTERM. withchild: also starts a child that only a group signal stops.
mkdir -p "$WORK/bin"
cat > "$BIN/reach-daemon" <<'EOF'
#!/bin/sh
case "$1" in
  stubborn)  trap '' TERM ;;
  withchild) sleep 300 & echo $! > "$CHILD_FILE"; trap 'exit 0' TERM ;;
  *)         trap 'exit 0' TERM ;;
esac
while :; do sleep 0.1; done
EOF
chmod +x "$BIN/reach-daemon"
start_daemon() { # start_daemon <mode> <pidfile> -> pid
  local pid
  pid="$(python3 -c 'import subprocess,sys; p=subprocess.Popen([sys.argv[1], sys.argv[2]], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); print(p.pid)' "$BIN/reach-daemon" "$1")"
  echo "$pid" >> "$PIDS_FILE"
  mkdir -p "$(dirname "$2")"
  echo "$pid" > "$2"
  sleep 0.5   # the shell has started and installed its trap
  echo "$pid"
}
alive() { kill -0 "$1" 2>/dev/null; }
stop() { bash -c "set -euo pipefail; source '$FUNCS'; stop_managed_daemon; echo returned-from-stop" 2>&1; }
PIDFILE="$XDG_RUNTIME_DIR/reach-vibe/reach-vibe.pid"

# 1. A running daemon is stopped by SIGTERM, and the installed reachctl is never asked.
pid="$(start_daemon term "$PIDFILE")"
alive "$pid" || fail "the stand-in daemon did not start"
out="$(stop)" || fail "stopping a running daemon failed: $out"
alive "$pid" && fail "the daemon is still running after the stop"
grep -q returned-from-stop <<<"$out" || fail "the installer did not continue: $out"
[[ ! -s "$STUB_LOG" ]] || fail "the old reachctl was called: $(cat "$STUB_LOG")"
echo "PASS a running daemon is stopped by the operating system; the old reachctl is never called"

# 2. A daemon that ignores SIGTERM gets SIGKILL after the wait.
pid="$(start_daemon stubborn "$PIDFILE")"
out="$(REACHABLE_DAEMON_STOP_TERM_SECONDS=1 stop)" || fail "a stubborn daemon halted the installer: $out"
alive "$pid" && fail "a daemon that ignores SIGTERM survived"
grep -q 'sending SIGKILL' <<<"$out" || fail "SIGKILL was not announced: $out"
echo "PASS a daemon that ignores SIGTERM is killed after the wait"

# 3. A daemon that cannot be killed halts the installer loudly; it does not go on to replace the runtime.
pid="$(start_daemon stubborn "$PIDFILE")"
set +e
out="$(REACHABLE_DAEMON_STOP_TERM_SECONDS=1 REACHABLE_DAEMON_STOP_KILL_SECONDS=1 bash -c "set -euo pipefail; source '$FUNCS'; kill() { case \"\$1\" in -KILL) return 0;; esac; builtin kill \"\$@\"; }; stop_managed_daemon; echo returned-from-stop" 2>&1)"
rc=$?
set -e
[[ $rc -eq 1 ]] || fail "a daemon that refuses to die: expected exit 1, got $rc: $out"
grep -q returned-from-stop <<<"$out" && fail "the installer went on past a daemon it could not stop"
grep -q 'refused to die' <<<"$out" || fail "the refusal is not explained: $out"
kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
echo "PASS a daemon that will not die halts the installer with a clear message"

# 4. A stale pid file whose pid another program reused is never signalled (the identity check).
sleep 300 & other=$!
echo "$other" >> "$PIDS_FILE"
echo "$other" > "$PIDFILE"
out="$(stop)" || fail "a stale pid file halted the installer: $out"
alive "$other" || fail "an unrelated program that reused the pid was killed"
grep -q 'no running Reachable daemon found' <<<"$out" || fail "stale pid file: wrong message: $out"
kill "$other" 2>/dev/null || true
echo "PASS a pid file whose pid belongs to another program is left alone"

# 5. No pid file at all: nothing to stop, the installer goes on.
rm -f "$PIDFILE"
out="$(stop)" || fail "no daemon: the installer halted: $out"
grep -q 'no running Reachable daemon found' <<<"$out" || fail "no daemon: wrong message: $out"
echo "PASS no daemon: nothing is stopped and the installer goes on"

# 6. The daemon's whole process group stops, so its scan workers do not outlive it.
export CHILD_FILE="$WORK/child.pid"
pid="$(start_daemon withchild "$PIDFILE")"
child="$(cat "$CHILD_FILE")"
alive "$child" || fail "the stand-in child did not start"
stop >/dev/null || fail "stopping a daemon with a child failed"
alive "$pid" && fail "the daemon survived"
alive "$child" && { kill "$child" 2>/dev/null || true; fail "the daemon's child outlived the stop"; }
echo "PASS the daemon's process group stops with it"

# 7. A bare Linux host: no XDG_RUNTIME_DIR, no /run/user. The pid file in /tmp/runtime-<uid> is found, and the
#    installer creates no folder of its own.
uid="$(id -u)"
if [[ -e "/tmp/runtime-$uid" ]]; then
  echo "SKIP 7: /tmp/runtime-$uid exists on this host and is not ours to touch"
else
  pid="$(env -u XDG_RUNTIME_DIR bash -c "$(declare -f start_daemon alive); BIN='$BIN'; PIDS_FILE='$PIDS_FILE'; start_daemon term '/tmp/runtime-$uid/reach-vibe/reach-vibe.pid'")"
  alive "$pid" || fail "bare host: the stand-in daemon did not start"
  out="$(env -u XDG_RUNTIME_DIR bash -c "set -euo pipefail; source '$FUNCS'; stop_managed_daemon; echo returned-from-stop" 2>&1)" || fail "bare host: $out"
  alive "$pid" && fail "bare host: the daemon survived"
  rm -rf "/tmp/runtime-$uid"
  echo "PASS a bare host (no XDG_RUNTIME_DIR, no /run/user): the daemon is found in /tmp/runtime-$uid and stopped"
fi
env -u XDG_RUNTIME_DIR bash -c "set -euo pipefail; source '$FUNCS'; stop_managed_daemon" >/dev/null 2>&1 || fail "stop with no daemon failed"
[[ ! -e "/tmp/runtime-$uid" ]] || fail "the installer created /tmp/runtime-$uid: it must never create a runtime folder"
echo "PASS the installer creates no runtime folder"

# 8. The stop never asks the installed runtime anything, in the code itself.
if sed -n '/^stop_managed_daemon() {/,/^}/p' "$ROOT_DIR/install.sh" | grep -v '^\s*#' | grep -qE 'reachctl|daemon stop'; then
  fail "stop_managed_daemon refers to reachctl: an upgrade must not depend on the old runtime's code"
fi
echo "PASS stop_managed_daemon never refers to the installed reachctl"

# 9. Every removal site in install.sh is immediately preceded by the stop call.
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

# 10. macOS: the daemon runs under the Homebrew/framework Python, so its command line carries NO path of the managed
#     venv: `<framework>/Python.app/Contents/MacOS/Python -m reach_agent -v _daemon --repo <app>` (measured 2026-11-28 on
#     the machine that hit the upgrade failure). The identity is the daemon command, as the product's own uninstall
#     decides it, not a path. Without it the installer finds no daemon and replaces the venv under a live one.
mkdir -p "$WORK/framework/Python.app/Contents/MacOS" "$WORK/app"
cat > "$WORK/framework/Python.app/Contents/MacOS/Python" <<'EOF2'
#!/bin/sh
trap 'exit 0' TERM
while :; do sleep 0.1; done
EOF2
chmod +x "$WORK/framework/Python.app/Contents/MacOS/Python"
mac_pid="$(python3 -c 'import subprocess,sys; p=subprocess.Popen([sys.argv[1], "-m", "reach_agent", "-v", "_daemon", "--repo", sys.argv[2]], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); print(p.pid)' "$WORK/framework/Python.app/Contents/MacOS/Python" "$WORK/app")"
echo "$mac_pid" >> "$PIDS_FILE"
echo "$mac_pid" > "$PIDFILE"
sleep 0.5
alive "$mac_pid" || fail "macOS: the stand-in daemon did not start"
out="$(stop)" || fail "macOS: stopping the daemon failed: $out"
alive "$mac_pid" && fail "macOS: a daemon whose command line has no venv path was not stopped (it would run under a replaced venv)"
echo "PASS a macOS daemon (framework Python, no venv path in its command line) is found and stopped"

# 11. A program that only mentions reach_agent is not the daemon.
sleep 300 & other=$!
echo "$other" >> "$PIDS_FILE"
echo "$other" > "$PIDFILE"
out="$(stop)" || fail "a look-alike halted the installer: $out"
alive "$other" || fail "a program that is not the daemon was killed"
kill "$other" 2>/dev/null || true
echo "PASS only the daemon command is matched"
echo "OK"
