#!/usr/bin/env bash
# No GitHub token ever appears in a process's argv.
#
# Until 2026-10-27 the release-tag resolver ran
#   python3 -c "..." "$tag" GITHUB_TOKEN="$GITHUB_TOKEN" MCP_GITHUB_TOKEN="..."
# so the token sat in python3's argv, readable by every user through `ps`
# (CWE-214) -- and the script reads the token from the environment anyway.
# This runs the real resolve_version_from_release_tag from install.sh with a
# recording curl and a recording python3 on PATH, a token set, and a GitHub
# "rate limit" reply, and checks every argv either one saw.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

REAL_PY="$(command -v python3)"
FUNCS="$WORK/funcs.sh"
for fn in github_curl resolve_version_from_release_tag; do
  sed -n "/^${fn}() {/,/^}/p" "$ROOT_DIR/install.sh" >> "$FUNCS"
  grep -q "^${fn}() {" "$FUNCS" || fail "could not extract ${fn}"
done
# Present only once the fix is in; the resolver calls it when it exists.
sed -n "/^api_token_state() {/,/^}/p" "$ROOT_DIR/install.sh" >> "$FUNCS"

mkdir -p "$WORK/bin"
cat > "$WORK/bin/curl" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$WORK/curl.args"
cat > /dev/null
echo '{"message": "API rate limit exceeded for 10.0.0.1."}'
EOF
cat > "$WORK/bin/python3" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$WORK/python3.args"
exec "$REAL_PY" "\$@"
EOF
chmod +x "$WORK/bin/curl" "$WORK/bin/python3"

MARKER="ghp_argv_leak_marker_7f3a9c"
set +e
env PATH="$WORK/bin:$PATH" GITHUB_TOKEN="$MARKER" MCP_GITHUB_TOKEN="$MARKER" bash -c "
  set -uo pipefail
  REPO=sthenos-security/reach-dist
  RELEASES_API_TOKEN=\$GITHUB_TOKEN
  REACHABLE_DOWNLOAD_CONNECT_TIMEOUT=20
  REACHABLE_API_MAX_TIME=60
  source '$FUNCS'
  resolve_version_from_release_tag v1.0.0b1
" > "$WORK/out" 2> "$WORK/err"
rc=$?
set -e

[[ $rc -ne 0 ]] || fail "a rate-limited GitHub reply must not resolve a version"
touch "$WORK/curl.args" "$WORK/python3.args"
if grep -q "$MARKER" "$WORK/python3.args"; then
  fail "the GitHub token appears in python3's argv: $(grep "$MARKER" "$WORK/python3.args" | head -1 | cut -c1-160)"
fi
if grep -q "$MARKER" "$WORK/curl.args"; then
  fail "the GitHub token appears in curl's argv"
fi
echo "PASS no token in any argv"

grep -q "even with GITHUB_TOKEN" "$WORK/err" \
  || fail "with a token configured, the rate-limit message must say so: $(cat "$WORK/err")"
echo "PASS the parser still knows a token is configured"
echo "OK"
