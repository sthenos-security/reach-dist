#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$WORK/bundle/wheelhouse" "$WORK/mirror" "$WORK/home"
printf '{"version":"1.0.0b240"}\n' > "$WORK/bundle/reachable-signed-manifest.json"

# Argument validation happens before setup, even in source-only mode.
if HOME="$WORK/home" REACHABLE_INSTALLER_SOURCE_ONLY=1 bash "$ROOT/install.sh" --install-only >"$WORK/out" 2>&1; then
    fail "accepted --install-only without --bundle"
fi
grep -q 'requires --bundle' "$WORK/out" || fail "missing bundle diagnostic"
if HOME="$WORK/home" REACHABLE_INSTALLER_SOURCE_ONLY=1 bash "$ROOT/install.sh" --bundle "$WORK/bundle" --install-only --mirror-root "$WORK/mirror" >"$WORK/out" 2>&1; then
    fail "accepted mirror with --install-only"
fi
grep -q 'cannot be combined with --mirror-root' "$WORK/out" || fail "missing mirror diagnostic"
if HOME="$WORK/home" REACHABLE_INSTALLER_SOURCE_ONLY=1 bash "$ROOT/install.sh" --bundle "$WORK/bundle" >"$WORK/out" 2>&1; then
    fail "full bundle mode accepted missing mirror"
fi
grep -q 'needs --mirror-root' "$WORK/out" || fail "full mode mirror check removed"

# Run the actual parsed bundle branch, replacing expensive operations at the
# main boundary. The normal download_and_install still contains the signature
# verifier and offline --require-hashes install; install-only must reach it.
export HOME="$WORK/home" REACHABLE_INSTALLER_SOURCE_ONLY=1
# shellcheck source=install.sh
source "$ROOT/install.sh" --bundle "$WORK/bundle" --install-only
[[ "$INSTALL_ONLY" == true && "$REACHABLE_AIRGAP_BUNDLE_ROOT" == "$WORK/bundle" ]] || fail "bundle not selected"
configure_venv_pip_config
grep -q '^no-index = true$' "$HOME/.reachable/venv/pip.conf" || fail "pip is not offline"
grep -Fxq "find-links = $WORK/bundle/wheelhouse" "$HOME/.reachable/venv/pip.conf" || fail "wheelhouse not selected"
trace="$WORK/trace"
print_header() { :; }
print_ok() { :; }
print_info() { :; }
detect_environment() { echo detect >> "$trace"; }
handle_existing_install() { echo existing >> "$trace"; }
download_and_install() { echo download_and_install >> "$trace"; }
verify_installation() { echo verify_installation >> "$trace"; }
run_vibe_setup() { echo run_vibe_setup >> "$trace"; }
print_success() { echo print_success >> "$trace"; }
main
[[ "$(cat "$trace")" == $'detect\nexisting\ndownload_and_install' ]] || fail "install-only ran post-install setup: $(cat "$trace")"
INSTALL_ONLY=false
main
[[ "$(tail -n 6 "$trace")" == $'detect\nexisting\ndownload_and_install\nverify_installation\nrun_vibe_setup\nprint_success' ]] || fail "full mode changed"

grep -Fq -- '--artifact-root "$REACHABLE_AIRGAP_BUNDLE_ROOT" --expected-scope "$BUNDLE_SCOPE"' "$ROOT/install.sh" || fail "bundle verification removed"
grep -Fq -- 'pip install --no-deps --require-hashes' "$ROOT/install.sh" || fail "locked install removed"
echo 'PASS: bundle install-only selection and full-mode preservation'