#!/usr/bin/env bash
# The candidate transport is private, but its manifest is signed and must be
# channel-bound. Extract argument validation without running an installation.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$ROOT_DIR/install.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# The production guard must be present before the unrelated install-surface
# resolution. Exercise the exact guard shell with synthetic parsed values;
# executing the whole installer would start its real install path.
guard_start=$(grep -n '^case "\$INSTALL_CHANNEL" in$' "$INSTALLER" | cut -d: -f1)
guard_end=$(grep -n '^# Resolve the install surface once' "$INSTALLER" | cut -d: -f1)
[[ -n "$guard_start" && -n "$guard_end" ]] || fail "could not locate channel validation"
sed -n "${guard_start},$((guard_end - 1))p" "$INSTALLER" > "$WORK/guard.sh"

run_case() { # name channel token dist_root dist_base
  local name="$1" channel="$2" token="$3" dist_root="$4" dist_base="$5"
  set +e
  INSTALL_CHANNEL="$channel" RELEASES_API_TOKEN="$token" \
    REACHABLE_DIST_ROOT="$dist_root" REACHABLE_DIST_BASE_URL="$dist_base" \
    bash "$WORK/guard.sh" >"$WORK/$name.out" 2>&1
  local rc=$?
  set -e
  printf '%s' "$rc" >"$WORK/$name.rc"
}

run_case bad preview '' '' ''
[[ "$(cat "$WORK/bad.rc")" == 2 ]] || fail "unknown channel was accepted"
grep -Fq -- '--channel must be public or candidate' "$WORK/bad.out" || fail "unknown channel failure was not named"

run_case no-token candidate '' /tmp/candidate ''
[[ "$(cat "$WORK/no-token.rc")" == 2 ]] || fail "candidate without token was accepted"
grep -Fq 'requires the CI-only release-assets token' "$WORK/no-token.out" || fail "missing-token failure was not named"

run_case no-base candidate test-token '' ''
[[ "$(cat "$WORK/no-base.rc")" == 2 ]] || fail "candidate without source was accepted"
grep -Fq 'requires --dist-root or --dist-base-url' "$WORK/no-base.out" || fail "missing-source failure was not named"

run_case public-private public '' /tmp/candidate ''
[[ "$(cat "$WORK/public-private.rc")" == 2 ]] || fail "public channel accepted candidate source"
grep -Fq 'candidate-only' "$WORK/public-private.out" || fail "public/candidate separation failure was not named"

run_case candidate-ok candidate test-token /tmp/candidate ''
[[ "$(cat "$WORK/candidate-ok.rc")" == 0 ]] || fail "well-formed candidate selection failed: $(cat "$WORK/candidate-ok.out")"

echo "installer channel-selection test passed"