#!/usr/bin/env bash
# install.sh must not pass `--ci` to `reachctl vibe wire-workspace`.
#
# Until 2026-10-27 run_vibe_setup ran `wire-workspace --repo W --ci` on every
# install. In reach-core `--ci` made wire-workspace install the Gate 1
# guardrail skills without forcing them, so any host with CI set got none
# (decision D-4: CI never skips security; reach-core 5b8136c0 removed that
# coupling). The only other thing `--ci` does is a `reachctl doctor --ci` tool
# preflight, which install.sh has already done itself (`doctor --full` in
# verify_installation), and SINGLE-INSTALL-MODE says install.sh adds no CI
# behaviour of its own. This runs the real run_vibe_setup with a stub
# reachctl that records its argv.
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
print_error() { echo "  ERROR $1" >&2; }
log_event()   { :; }
PUBLIC_INSTALL_URL="https://example.invalid/install.sh"
REACHABLE_INSTALLER_AGENT_SETUP=0
ENABLE_VIBE_CODING=true
VIBE_SURFACE_REASON="--vibe"
VIBE_AGENTS=(claude-code)
VIBE_RUN_BASELINE=false
VIBE_SETUP_FAILED=""
EOS

export HOME="$WORK/home"
export STUB_LOG="$WORK/argv"
mkdir -p "$HOME/.reachable/venv/bin" "$HOME/proj"
cat > "$HOME/.reachable/venv/bin/reachctl" <<'EOS'
#!/bin/sh
echo "$*" >> "$STUB_LOG"
exit 0
EOS
chmod +x "$HOME/.reachable/venv/bin/reachctl"

# Same answer whether or not the host looks like CI: install.sh never decides.
for ci in "" true; do
  : > "$STUB_LOG"
  CI="$ci" INSTALL_LOG="$WORK/install.log" REACHABLE_TMP_ROOT="$WORK" \
    bash -c "source '$FUNCS'; VIBE_WORKSPACE='$HOME/proj'; run_vibe_setup" >"$WORK/out" 2>&1 \
    || fail "run_vibe_setup failed (CI='$ci'): $(cat "$WORK/out")"
  wire="$(grep -E '^vibe wire-workspace ' "$STUB_LOG" || true)"
  [[ -n "$wire" ]] || fail "wire-workspace was not called (CI='$ci'): $(cat "$STUB_LOG")"
  case " $wire " in
    *" --ci "*) fail "install.sh passes --ci to wire-workspace (CI='$ci'): $wire" ;;
  esac
  case " $wire " in
    *" --agent claude_code "*) ;;
    *) fail "agent not forwarded (CI='$ci'): $wire" ;;
  esac
  echo "PASS CI='${ci:-unset}': $wire"
done
echo "OK"
