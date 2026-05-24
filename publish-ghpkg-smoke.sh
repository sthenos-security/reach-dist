#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SCRIPT_DIR/packages/reach-ghpkg-smoke-fixture"
PKG_NAME="@sthenos-security/reach-ghpkg-smoke-fixture"
PKG_VERSION="0.0.0-smoke.1"
TMP_NPMRC="$(mktemp "${TMPDIR:-/tmp}/ghpkg-publish.XXXXXX")"
TMP_GLOBAL_NPMRC="$(mktemp "${TMPDIR:-/tmp}/ghpkg-global.XXXXXX")"
TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/ghpkg-home.XXXXXX")"

cleanup() {
    rm -f "$TMP_NPMRC"
    rm -f "$TMP_GLOBAL_NPMRC"
    rm -rf "$TMP_HOME"
    unset NODE_AUTH_TOKEN || true
    unset NPM_CONFIG_USERCONFIG || true
}
trap cleanup EXIT

if ! command -v npm >/dev/null 2>&1; then
    echo "npm is required but was not found on PATH" >&2
    exit 1
fi

read -rsp "GitHub classic PAT for npm.pkg.github.com publish: " NODE_AUTH_TOKEN
echo

cat >"$TMP_NPMRC" <<EOF
@sthenos-security:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}
EOF

touch "$TMP_GLOBAL_NPMRC"

run_npm() {
    HOME="$TMP_HOME" npm --userconfig "$TMP_NPMRC" --globalconfig "$TMP_GLOBAL_NPMRC" "$@"
}

echo "Publishing $PKG_NAME from $PKG_DIR"
(
    cd "$PKG_DIR"
    run_npm whoami --registry=https://npm.pkg.github.com
    run_npm publish --registry=https://npm.pkg.github.com
)

echo
echo "Published package:"
echo "  ${PKG_NAME}@${PKG_VERSION}"
echo
echo "Next test command:"
echo "  cd /Users/alaindazzi/src/reach-core"
echo "  ./scripts/test-github-package.sh ${PKG_NAME} ${PKG_VERSION}"
