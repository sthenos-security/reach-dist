#!/bin/bash
# REACHABLE Local Installation Script
#
# Usage:
#   ./install.sh reachable-4.5.9-cp311-cp311-macosx_14_0_arm64.whl
#
# This script:
# 1. Creates a virtual environment
# 2. Installs the wheel
# 3. Installs syft and grype
# 4. Runs selftest

set -e

WHEEL="$1"

if [ -z "$WHEEL" ]; then
    echo "Usage: $0 <wheel-file>"
    echo ""
    echo "Example:"
    echo "  $0 reachable-4.5.9-cp311-cp311-macosx_14_0_arm64.whl"
    exit 1
fi

if [ ! -f "$WHEEL" ]; then
    echo "❌ Wheel file not found: $WHEEL"
    exit 1
fi

echo "======================================"
echo "REACHABLE Installer"
echo "======================================"
echo ""
echo "Wheel: $WHEEL"
echo ""

# Detect platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
echo "Platform: ${OS} / ${ARCH}"

# Check Python
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo "Python: ${PYTHON_VERSION}"

# Create venv if not in one
if [ -z "$VIRTUAL_ENV" ]; then
    echo ""
    echo "📦 Creating virtual environment..."
    
    VENV_DIR="${HOME}/.reachable-env"
    if [ -d "$VENV_DIR" ]; then
        echo "   Using existing: $VENV_DIR"
    else
        python3 -m venv "$VENV_DIR"
        echo "   Created: $VENV_DIR"
    fi
    
    source "$VENV_DIR/bin/activate"
    echo "   ✅ Activated"
fi

# Install wheel
echo ""
echo "📦 Installing REACHABLE..."
pip install --upgrade pip -q
pip install "$WHEEL" -q
echo "   ✅ Installed"

# Install external tools
echo ""
echo "📦 Installing external tools..."

INSTALL_DIR="${HOME}/bin"
mkdir -p "$INSTALL_DIR"

# Syft
if ! command -v syft &> /dev/null; then
    echo "   Installing syft..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b "$INSTALL_DIR" 2>/dev/null
    echo "   ✅ syft installed"
else
    echo "   ✅ syft already installed"
fi

# Grype
if ! command -v grype &> /dev/null; then
    echo "   Installing grype..."
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b "$INSTALL_DIR" 2>/dev/null
    echo "   ✅ grype installed"
else
    echo "   ✅ grype already installed"
fi

# Update PATH if needed
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    export PATH="${INSTALL_DIR}:$PATH"
    echo ""
    echo "⚠️  Add to your shell profile:"
    echo "   export PATH=\"${INSTALL_DIR}:\$PATH\""
fi

# Run selftest
echo ""
echo "======================================"
echo "Running verification..."
echo "======================================"
reachctl selftest || echo "⚠️  Some checks failed"

echo ""
echo "======================================"
echo "✅ Installation Complete"
echo "======================================"
echo ""
echo "To use REACHABLE:"
echo ""
echo "  # Activate environment (if not already)"
echo "  source ~/.reachable-env/bin/activate"
echo ""
echo "  # Scan a repository"
echo "  reachctl scan /path/to/your/repo"
echo ""
echo "  # View dashboard"
echo "  open ~/.reachable/scans/REPO/latest/dashboard/index.html"
echo ""
