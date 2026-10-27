#!/usr/bin/env bash
# The latest version comes from the first-party manifest only, and every
# metadata request is bounded.
#
# Until 2026-10-27 resolve_version fell back, when latest.json could not be
# fetched, to the newest entry of the reach-dist GitHub releases API -- a
# second, unvetted version source (INSTALLER-ATTESTATION §13.2). The metadata
# requests also had no --max-time, so a stalled endpoint hung the install.
# This runs the real resolve_version / github_curl from install.sh against a
# recording curl.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

FUNCS="$WORK/funcs.sh"
for fn in github_curl _manifest_version_from_json resolve_version; do
  sed -n "/^${fn}() {/,/^}/p" "$ROOT_DIR/install.sh" >> "$FUNCS"
  grep -q "^${fn}() {" "$FUNCS" || fail "could not extract ${fn}"
done
# The pre-2026-10-27 helper; absent once the fix is in.
sed -n "/^resolve_version_from_manifest() {/,/^}/p" "$ROOT_DIR/install.sh" >> "$FUNCS"

mkdir -p "$WORK/bin"
cat > "$WORK/bin/curl" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$WORK/curl.args"
out=""
prev=""
for a in "\$@"; do
  if [ "\$prev" = "-o" ]; then out="\$a"; fi
  prev="\$a"
done
case "\$*" in
  *api.github.com*)
    echo '[{"tag_name": "v9.9.9"}]'
    exit 0 ;;
  *latest.json*)
    if [ "\$LATEST_MODE" = fail ]; then
      echo "curl: (22) The requested URL returned error: 503" >&2
      exit 22
    fi
    body='{"ok": true, "version": "1.0.0b247"}'
    if [ -n "\$out" ]; then printf '%s\n' "\$body" > "\$out"; else printf '%s\n' "\$body"; fi
    exit 0 ;;
esac
cat > /dev/null
exit 0
EOF
chmod +x "$WORK/bin/curl"

run() { # run <LATEST_MODE> <shell snippet>
  env PATH="$WORK/bin:$PATH" LATEST_MODE="$1" bash -c "
    set -uo pipefail
    REPO=sthenos-security/reach-dist
    RELEASES_API_TOKEN=
    LATEST_MANIFEST_URL=https://sthenosec.com/download/latest.json
    REACHABLE_DOWNLOAD_CONNECT_TIMEOUT=20
    REACHABLE_API_MAX_TIME=60
    source '$FUNCS'
    $2
  "
}

# 1. latest.json unavailable: no second source, a failure naming the URL.
: > "$WORK/curl.args"
set +e
run fail 'resolve_version' > "$WORK/out" 2> "$WORK/err"
rc=$?
set -e
grep -q "9.9.9" "$WORK/out" && fail "an unavailable manifest resolved the GitHub API's newest release (9.9.9)"
[[ $rc -ne 0 ]] || fail "an unavailable manifest must fail version resolution, got rc=0 and '$(cat "$WORK/out")'"
grep -q "api.github.com" "$WORK/curl.args" && fail "resolve_version called the GitHub releases API"
grep -q "https://sthenosec.com/download/latest.json" "$WORK/err" \
  || fail "the failure must name the manifest URL: $(cat "$WORK/err")"
echo "PASS no fallback version source; the failure names the manifest"

# 2. latest.json available: its version, fetched with a bound.
: > "$WORK/curl.args"
got="$(run ok 'resolve_version')"
[[ "$got" == "1.0.0b247" ]] || fail "expected 1.0.0b247 from the manifest, got '$got'"
grep "latest.json" "$WORK/curl.args" | grep -q -- "--max-time" \
  || fail "the latest.json request has no --max-time: $(grep latest.json "$WORK/curl.args")"
echo "PASS the manifest's version, bounded request"

# 3. every GitHub API request is bounded.
: > "$WORK/curl.args"
run ok 'github_curl -sL https://api.github.com/repos/x/releases/tags/v1' > /dev/null
grep -q -- "--max-time" "$WORK/curl.args" \
  || fail "github_curl requests have no --max-time: $(cat "$WORK/curl.args")"
echo "PASS GitHub API requests are bounded"
echo "OK"
