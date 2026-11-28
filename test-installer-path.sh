#!/usr/bin/env bash
# The installer must not put Reachable's private venv on the user's PATH: `python3`, `pip` and every tool in
# venv/bin then resolved to Reachable's interpreter in every project (found 2026-11-28 on a real machine). It puts a
# launcher folder ~/.reachable/bin on PATH that holds only `reachctl` and `reachable`. The shell rc file is edited
# in place: the user's other lines survive, a symlinked rc file stays a symlink, and the old line is migrated.
# Runs the real function of install.sh on a fake HOME (the rc file holds a dummy secret-looking line).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

FUNCS="$WORK/funcs.sh"
awk '/^_shell_rc_path\(\) \{/{p=1} /^# Detect Environment/{p=0} p' "$ROOT_DIR/install.sh" > "$FUNCS"
grep -q '^configure_shell_path() {' "$FUNCS" || fail "could not extract configure_shell_path"
grep -q '^link_launchers() {' "$FUNCS" || fail "install.sh has no link_launchers"
cat >> "$FUNCS" <<'EOT'
print_info()  { echo "  $1"; }
print_warn()  { echo "  WARN $1"; }
print_error() { echo "  ERROR $1" >&2; }
EOT

fresh_home() {
  export HOME="$WORK/$1" SHELL=/bin/zsh
  mkdir -p "$HOME/.reachable/venv/bin"
  for tool in reachctl reachable python3 pip semgrep; do
    printf '#!/bin/sh\necho %s\n' "$tool" > "$HOME/.reachable/venv/bin/$tool"
    chmod +x "$HOME/.reachable/venv/bin/$tool"
  done
}
run() { bash -c "set -euo pipefail; source '$FUNCS'; $1" 2>&1; }
OLD_LINE='export PATH="$HOME/.reachable/venv/bin:$PATH"'
NEW_LINE='export PATH="$HOME/.reachable/bin:$PATH"'

# 1. The launcher folder holds exactly reachctl and reachable, both working, and nothing else.
fresh_home a
printf 'export DUMMY_TOKEN=not-a-real-secret-0000\nalias ll="ls -l"\n' > "$HOME/.zshrc"
run 'configure_shell_path' >/dev/null || fail "configure_shell_path failed"
listing="$(ls "$HOME/.reachable/bin" | tr '\n' ' ')"
[[ "$listing" == "reachable reachctl " ]] || fail "the launcher folder holds: $listing"
[[ "$("$HOME/.reachable/bin/reachctl")" == reachctl ]] || fail "reachctl through the launcher does not run the venv's"
echo "PASS the launcher folder holds only reachctl and reachable"

# 2. PATH gets the launcher folder, never the venv: python3 and pip stay the user's.
grep -qxF "$NEW_LINE" "$HOME/.zshrc" || fail "the rc file lacks the launcher PATH line"
if grep -qF '.reachable/venv/bin' "$HOME/.zshrc"; then fail "the rc file still puts the venv on PATH"; fi
echo "PASS the shell PATH line names the launcher folder, not the venv"

# 3. The user's other lines survive.
grep -qxF 'export DUMMY_TOKEN=not-a-real-secret-0000' "$HOME/.zshrc" || fail "a user line was lost"
grep -qxF 'alias ll="ls -l"' "$HOME/.zshrc" || fail "a user line was lost"
echo "PASS the user's other rc lines are kept"

# 4. Migration: a machine that has the old line gets it replaced, once, and a second run changes nothing.
fresh_home b
printf 'export KEEP=1\n\n# Added by REACHABLE installer\n%s\nexport AFTER=2\n' "$OLD_LINE" > "$HOME/.zshrc"
run 'configure_shell_path' >/dev/null || fail "migration failed"
if grep -qF '.reachable/venv/bin' "$HOME/.zshrc"; then fail "the old venv PATH line was not removed"; fi
[[ "$(grep -cxF "$NEW_LINE" "$HOME/.zshrc")" == 1 ]] || fail "the new line is not there exactly once"
grep -qxF 'export KEEP=1' "$HOME/.zshrc" && grep -qxF 'export AFTER=2' "$HOME/.zshrc" || fail "migration lost a user line"
before="$(cat "$HOME/.zshrc")"
run 'configure_shell_path' >/dev/null || fail "second run failed"
[[ "$(cat "$HOME/.zshrc")" == "$before" ]] || fail "a second run changed the rc file"
echo "PASS the old line is migrated once and a second run changes nothing"

# 5. A symlinked rc file stays a symlink; the real file is what changes.
fresh_home c
mkdir -p "$HOME/dotfiles" && printf 'export REAL=1\n' > "$HOME/dotfiles/zshrc" && ln -s "$HOME/dotfiles/zshrc" "$HOME/.zshrc"
run 'configure_shell_path' >/dev/null || fail "symlinked rc: failed"
[[ -L "$HOME/.zshrc" ]] || fail "the symlinked rc file was replaced by a plain file"
grep -qxF "$NEW_LINE" "$HOME/dotfiles/zshrc" || fail "the symlink's target was not updated"
echo "PASS a symlinked rc file stays a symlink"

# 6. After the PATH change, `python3` and `pip` still resolve to what they did before.
fresh_home d
mkdir -p "$WORK/system/bin" && printf '#!/bin/sh\necho system-python\n' > "$WORK/system/bin/python3" && chmod +x "$WORK/system/bin/python3"
out="$(PATH="$WORK/system/bin:/usr/bin:/bin" bash -c "source '$FUNCS'; configure_shell_path >/dev/null; python3")"
[[ "$out" == system-python ]] || fail "python3 resolves to '$out' after the PATH change"
echo "PASS python3 is still the user's after the PATH change"
echo "OK"
