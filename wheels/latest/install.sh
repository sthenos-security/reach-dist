#!/usr/bin/env bash
# REACHABLE — Latest Release Installer
# Resolves the latest release tag and delegates to the root installer.
#
# Usage (no auth required):
#   curl -sL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/wheels/latest/install.sh | bash
set -e
REPO="sthenos-security/reach-dist"
API="https://api.github.com/repos/${REPO}/releases/latest"
ROOT_INSTALLER="https://raw.githubusercontent.com/${REPO}/main/install.sh"
TAG=$(curl -sL -H "Accept: application/vnd.github+json" "$API" \
    | grep '"tag_name"' | head -1 \
    | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
VERSION="${TAG#v}"
if [[ -z "$VERSION" ]]; then
    echo "Error: could not resolve latest release from github.com/${REPO}" >&2
    exit 1
fi
echo "Latest release: ${TAG}"
exec bash <(curl -sL "$ROOT_INSTALLER") --version "$VERSION" "$@"
