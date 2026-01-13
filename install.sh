#!/usr/bin/env bash

# Copyright © 2026 Sthenos Security. All rights reserved.

set -euo pipefail

###############################################################################
# REACHABLE Private Distribution Installer
###############################################################################

VERSION="1.0.0-beta7"
PACKAGE_NAME="reachable"
REPO_OWNER="sthenos-security"
REPO_NAME="reach-dist"
REPO_REF="main"  # branch/tag/sha to download from

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
# Post-install instructions
###############################################################################

print_next_steps() {
  echo
  echo "============================================================"
  echo "✔ REACHABLE installed successfully!"
  echo "============================================================"
  echo
  echo "NEXT STEPS:"
  echo
  echo "1. ADD TO PATH (add to ~/.zshrc or ~/.bashrc):"
  echo
  echo '   export PATH="$HOME/.reachable/venv/bin:$PATH"'
  echo
  echo "   Then reload your shell:"
  echo "     source ~/.zshrc"
  echo
  echo "2. SET GITHUB TOKEN (for cloning vulnerable libraries):"
  echo
  echo "   export GITHUB_TOKEN='ghp_your_token_here'"
  echo
  echo "   Token requires 'repo' scope for read access to all repositories."
  echo "   Create at: https://github.com/settings/tokens"
  echo
  echo "   For Claude Desktop MCP integration, also set:"
  echo "   export MCP_GITHUB_TOKEN='ghp_your_token_here'"
  echo
  echo "3. RUN YOUR FIRST SCAN:"
  echo
  echo "   reachctl scan /path/to/your/repo"
  echo
  echo "   First scan takes ~1-2 min extra to download vulnerability databases."
  echo
  echo "OTHER COMMANDS:"
  echo "   reachctl doctor     # Check tool dependencies"
  echo "   reachctl primer     # Quick-start guide"
  echo "   reachctl version    # Show version info"
  echo
  echo "============================================================"
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
  python -m pip install --force-reinstall "$LOCAL_WHEEL" || fail "pip install failed"

  print_next_steps
  exit 0
}

###############################################################################
# GitHub auth
###############################################################################

require_github_token() {
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    cat <<EOF

  A GitHub Personal Access Token is required to download from a private repo.

  Classic PAT:
    • scope: repo

  Fine-grained PAT (recommended minimum):
    • Repository access: ${REPO_OWNER}/${REPO_NAME}
    • Contents: Read-only
    • Metadata: Read-only (required)

  Create token:
    • Fine-grained: https://github.com/settings/personal-access-tokens/new
    • Classic:      https://github.com/settings/tokens

  Or set:
    export GITHUB_TOKEN=ghp_xxxx

EOF
    read -s -p "  Enter GitHub Token: " GITHUB_TOKEN
    echo
    export GITHUB_TOKEN
  fi

  # Validate token early
  # Use classic-compatible header format ("token ..."). Fine-grained tokens also work with this.
  local tmp_body tmp_hdr http_code
  tmp_body="$(mktemp)"
  tmp_hdr="$(mktemp)"
  trap 'rm -f "$tmp_body" "$tmp_hdr"' RETURN

  http_code="$(curl -sS -L \
    -D "$tmp_hdr" \
    -o "$tmp_body" \
    -w "%{http_code}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/user" || true)"

  if [[ "$http_code" != "200" ]]; then
    echo
    echo "✗ Token validation failed (HTTP $http_code)"
    echo
    echo "  Response headers (selected):"
    grep -iE 'x-github|x-ratelimit|content-type|status' "$tmp_hdr" || true
    echo
    echo "  Response body (first 300 chars):"
    head -c 300 "$tmp_body" || true
    echo
    fail "Invalid GitHub token or insufficient permissions"
  fi
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
  PY_TAG="$($PYTHON_BIN - <<'EOF'
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

  # Determine platform tag based on OS, arch, and Python version
  if [[ "$OS" == "darwin" ]]; then
    # macOS universal2 wheels - platform tag varies by Python version
    # Python 3.10-3.11: macosx_10_9_universal2
    # Python 3.12-3.13: macosx_10_13_universal2
    # Python 3.14+:     macosx_10_15_universal2
    PLATFORM_TAG="$($PYTHON_BIN - <<'EOF'
import sys
minor = sys.version_info.minor
if minor <= 11:
    print("macosx_10_9_universal2")
elif minor <= 13:
    print("macosx_10_13_universal2")
else:
    print("macosx_10_15_universal2")
EOF
)"
  elif [[ "$OS" == "linux" ]]; then
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
      PLATFORM_TAG="linux_aarch64"
    else
      PLATFORM_TAG="linux_x86_64"
    fi
  else
    fail "Unsupported OS: $OS"
  fi

  # Convert VERSION like "1.0.0-beta7" -> "1.0.0b7" (PEP 440)
  WHEEL_VERSION="$(python3 - <<PY
import re
v="${VERSION}"
m=re.match(r"^(\d+\.\d+\.\d+)-beta(\d+)$", v)
print(f"{m.group(1)}b{m.group(2)}" if m else v)
PY
)"

  WHEEL_NAME="${PACKAGE_NAME}-${WHEEL_VERSION}-${PY_TAG}-${PY_TAG}-${PLATFORM_TAG}.whl"
  WHEEL_DIR="wheels/v${VERSION}"

  echo "  Package Information"
  echo "  ─────────────────────────────────────────────────────────────"
  echo "  Version:       ${VERSION}"
  echo "  Wheel:         ${WHEEL_NAME}"
  echo "  Directory:     ${WHEEL_DIR} (ref: ${REPO_REF})"
  echo
}

###############################################################################
# Download wheel from GitHub repo directory (Contents API)
###############################################################################

download_wheel() {
  echo "▶ Downloading wheel"
  echo "  Source: ${REPO_OWNER}/${REPO_NAME}/${WHEEL_DIR} (ref: ${REPO_REF})"

  local api_base dir_url tmp_body tmp_hdr http_code
  api_base="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents"
  dir_url="${api_base}/${WHEEL_DIR}?ref=${REPO_REF}"

  tmp_body="$(mktemp)"
  tmp_hdr="$(mktemp)"
  trap 'rm -f "$tmp_body" "$tmp_hdr"' RETURN

  # Fetch directory listing into a file (avoid JSONDecodeError due to empty/non-JSON stdin)
  http_code="$(curl -sS -L \
    -D "$tmp_hdr" \
    -o "$tmp_body" \
    -w "%{http_code}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "$dir_url" || true)"

  if [[ "$http_code" != "200" ]]; then
    echo
    echo "✗ GitHub API returned HTTP $http_code for directory listing"
    echo "  URL: $dir_url"
    echo
    echo "  Response headers (selected):"
    grep -iE 'x-github|x-ratelimit|content-type|status' "$tmp_hdr" || true
    echo
    echo "  Response body (first 400 chars):"
    head -c 400 "$tmp_body" || true
    echo
    fail "Cannot access ${WHEEL_DIR}. Check token access, SSO, and ref/path."
  fi

  # Validate listing is a JSON array and check for target wheel
  local found
  found="$(python3 - <<PY "$tmp_body"
import json, sys
p=sys.argv[1]
with open(p, "r", encoding="utf-8", errors="replace") as f:
    data=json.load(f)
want="${WHEEL_NAME}"
ok=any(i.get("type")=="file" and i.get("name")==want for i in data) if isinstance(data, list) else False
print("yes" if ok else "no")
PY
)"

  if [[ "$found" != "yes" ]]; then
    echo
    echo "✗ Compatible wheel not found in ${WHEEL_DIR}: ${WHEEL_NAME}"
    echo
    echo "  Available wheels:"
    python3 - <<'PY' "$tmp_body"
import json, sys
data=json.load(open(sys.argv[1], "r", encoding="utf-8", errors="replace"))
names=[i.get("name","") for i in data if i.get("type")=="file" and i.get("name","").endswith(".whl")]
for n in sorted(names):
    print(f"    • {n}")
PY
    echo
    fail "Build/publish mismatch: installer expects ${WHEEL_NAME} but it is not present."
  fi

  # Download the file contents as raw bytes
  local file_path file_url
  file_path="${WHEEL_DIR}/${WHEEL_NAME}"
  file_url="${api_base}/${file_path}?ref=${REPO_REF}"

  http_code="$(curl -sS -L \
    -D "$tmp_hdr" \
    -o "${WHEEL_NAME}" \
    -w "%{http_code}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.raw" \
    "$file_url" || true)"

  if [[ "$http_code" != "200" ]]; then
    echo
    echo "✗ Download failed (HTTP $http_code)"
    echo "  URL: $file_url"
    echo
    echo "  Response headers (selected):"
    grep -iE 'x-github|x-ratelimit|content-type|status' "$tmp_hdr" || true
    echo
    fail "Download failed (Contents API raw). Check PAT permissions / SSO."
  fi

  echo "  ✓ Downloaded ${WHEEL_NAME}"
  echo
}

###############################################################################
# Install downloaded wheel
###############################################################################

install_downloaded_wheel() {
  setup_venv
  python -m pip install --force-reinstall "./${WHEEL_NAME}" || fail "pip install failed"
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
print_next_steps

