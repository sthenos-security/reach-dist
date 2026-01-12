#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# REACHABLE Private Distribution Installer
###############################################################################

VERSION="1.0.0-beta7"
PACKAGE_NAME="reachable"
REPO_OWNER="sthenos-security"
REPO_NAME="reach-dist"

LOCAL_WHEEL="${1:-}"

###############################################################################
# Helpers
###############################################################################

print_banner() {
cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REACHABLE Private Distribution
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

print_installer() {
cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REACHABLE Installer v${VERSION}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

fail() {
  echo
  echo "✗ $1"
  exit 1
}

###############################################################################
# Virtual environment
###############################################################################

setup_venv() {
  VENV_DIR="${HOME}/.reachable/venv"

  if [[ ! -d "$VENV_DIR" ]]; then
    echo "▶ Creating virtual environment"
    python3 -m venv "$VENV_DIR"
  fi

  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"

  python -m pip install --upgrade pip >/dev/null
}

###############################################################################
# Local wheel install (NO GitHub, NO token)
###############################################################################

install_local_wheel() {
  [[ -f "$LOCAL_WHEEL" ]] || fail "Wheel not found: $LOCAL_WHEEL"

  echo
  echo "▶ Installing local wheel"
  echo "  Wheel: $LOCAL_WHEEL"
  echo

  setup_venv
  python -m pip install "$LOCAL_WHEEL" || fail "pip install failed"

  echo
  echo "✔ REACHABLE installed from local wheel"
  exit 0
}

###############################################################################
# GitHub auth
###############################################################################

require_github_token() {
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    cat <<EOF

  A GitHub Personal Access Token is required.
  Use your own GitHub account token (with 'repo' scope).

  Create one at: https://github.com/settings/tokens
  Or set: export GITHUB_TOKEN=ghp_xxxx

EOF
    read -s -p "  Enter GitHub Token: " GITHUB_TOKEN
    echo
    export GITHUB_TOKEN
  fi

  curl -sSf \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    https://api.github.com/user >/dev/null \
    || fail "Invalid GitHub token or insufficient permissions"
}

###############################################################################
# Environment detection
###############################################################################

detect_environment() {
  echo
  echo "▶ Detecting environment"
  echo

  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"

  PYTHON_BIN="${PYTHON:-python3}"
  PY_TAG="$($PYTHON_BIN - <<EOF
import sys
print(f"cp{sys.version_info.major}{sys.version_info.minor}")
EOF
)"

  echo "  System Information"
  echo "  ─────────────────────────────────────────────────────────────"
  echo "  OS:            ${OS}"
  echo "  Architecture:  ${ARCH}"
  echo "  Python:        $($PYTHON_BIN --version | awk '{print $2}') (${PY_TAG})"
  echo

  if [[ "$OS" == "darwin" ]]; then
    PLATFORM_TAG="macosx_10_15_universal2"
  elif [[ "$OS" == "linux" ]]; then
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
      PLATFORM_TAG="manylinux_2_28_aarch64"
    else
      PLATFORM_TAG="manylinux_2_28_x86_64"
    fi
  else
    fail "Unsupported OS: $OS"
  fi

  WHEEL_NAME="${PACKAGE_NAME}-${VERSION/beta/b}-${PY_TAG}-${PY_TAG}-${PLATFORM_TAG}.whl"

  echo "  Package Information"
  echo "  ─────────────────────────────────────────────────────────────"
  echo "  Version:       ${VERSION}"
  echo "  Wheel:         ${WHEEL_NAME}"
  echo
}

###############################################################################
# Download wheel from GitHub
###############################################################################

download_wheel() {
  echo "▶ Downloading wheel"
  echo "  Repository: ${REPO_OWNER}/${REPO_NAME}"

  RELEASE_JSON="$(curl -sSf \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/tags/v${VERSION})" \
    || fail "Release v${VERSION} not found"

  ASSET_ID="$(echo "$RELEASE_JSON" | python3 - <<EOF
import json, sys
data = json.load(sys.stdin)
for a in data.get("assets", []):
    if a["name"] == "${WHEEL_NAME}":
        print(a["id"])
        sys.exit(0)
sys.exit(1)
EOF
)"

  [[ -n "$ASSET_ID" ]] || fail "Compatible wheel not found"

  curl -L \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/octet-stream" \
    "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/assets/${ASSET_ID}" \
    -o "${WHEEL_NAME}" \
    || fail "Download failed"

  echo "  ✓ Downloaded ${WHEEL_NAME}"
  echo
}

###############################################################################
# Install downloaded wheel
###############################################################################

install_downloaded_wheel() {
  setup_venv
  python -m pip install "./${WHEEL_NAME}" || fail "pip install failed"
}

###############################################################################
# Main
###############################################################################

print_banner

# --- LOCAL MODE SHORT-CIRCUIT ---
if [[ -n "$LOCAL_WHEEL" ]]; then
  if [[ $# -gt 1 ]]; then
    fail "Too many arguments. Usage: install.sh [path/to/wheel]"
  fi
  install_local_wheel
fi

# --- REMOTE MODE ---
require_github_token
print_installer
detect_environment
download_wheel
install_downloaded_wheel

echo
echo "✔ Installation complete"
