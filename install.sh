#!/bin/bash
# =============================================================================
#
#  ██████╗ ███████╗ █████╗  ██████╗██╗  ██╗ █████╗ ██████╗ ██╗     ███████╗
#  ██╔══██╗██╔════╝██╔══██╗██╔════╝██║  ██║██╔══██╗██╔══██╗██║     ██╔════╝
#  ██████╔╝█████╗  ███████║██║     ███████║███████║██████╔╝██║     █████╗  
#  ██╔══██╗██╔══╝  ██╔══██║██║     ██╔══██║██╔══██║██╔══██╗██║     ██╔══╝  
#  ██║  ██║███████╗██║  ██║╚██████╗██║  ██║██║  ██║██████╔╝███████╗███████╗
#  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝
#
#  Installer (Direct Download Edition)
#  Copyright © 2026 Sthenos Security. All rights reserved.
#
#  Usage:
#    curl -sSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash
#
#  Requirements:
#    - Python 3.10+
#    - curl or wget
#
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
VERSION="1.0.0-beta5"
WHEEL_VERSION="1.0.0b5"
DIST_REPO="sthenos-security/reach-dist"
DIST_URL="https://github.com/${DIST_REPO}/releases/download/v${VERSION}"

# -----------------------------------------------------------------------------
# Colors & Formatting
# -----------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_step() {
    echo -e "\n${CYAN}▶${NC} ${BOLD}$1${NC}"
}

print_ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_info() {
    echo -e "  ${DIM}$1${NC}"
}

print_detail() {
    printf "  ${BOLD}%-14s${NC} %s\n" "$1" "$2"
}

# -----------------------------------------------------------------------------
# Detect Environment
# -----------------------------------------------------------------------------
detect_environment() {
    print_step "Detecting environment"
    
    # OS
    OS_RAW=$(uname -s)
    OS=$(echo "$OS_RAW" | tr '[:upper:]' '[:lower:]')
    case "$OS" in
        darwin) 
            OS_NAME="macOS"
            OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
            ;;
        linux)  
            OS_NAME="Linux"
            if [[ -f /etc/os-release ]]; then
                OS_VERSION=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
            else
                OS_VERSION=$(uname -r)
            fi
            ;;
        *)
            print_error "Unsupported OS: $OS_RAW"
            exit 1
            ;;
    esac
    
    # Architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  ARCH_NAME="x86_64 (Intel/AMD)" ;;
        aarch64) ARCH_NAME="ARM64" ;;
        arm64)   ARCH_NAME="ARM64 (Apple Silicon)" ;;
        *)       print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    # Python version
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        print_error "Python not found"
        echo ""
        echo "  Install Python 3.10+ first:"
        if [[ "$OS" == "darwin" ]]; then
            echo "    brew install python@3.12"
        else
            echo "    sudo apt install python3    # Debian/Ubuntu"
            echo "    sudo dnf install python3    # RHEL/Fedora"
        fi
        exit 1
    fi
    
    PY_VERSION=$($PYTHON_CMD -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PY_FULL=$($PYTHON_CMD -c "import sys; print(sys.version.split()[0])")
    PY_MAJOR=$(echo $PY_VERSION | cut -d. -f1)
    PY_MINOR=$(echo $PY_VERSION | cut -d. -f2)
    
    if [[ "$PY_MAJOR" -lt 3 ]] || [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 10 ]]; then
        print_error "Python 3.10+ required (found $PY_VERSION)"
        echo ""
        echo "  Supported versions: 3.10, 3.11, 3.12, 3.13, 3.14"
        exit 1
    fi
    
    PY_TAG="cp${PY_VERSION//./}"
    
    # Platform tag for wheel
    if [[ "$OS" == "darwin" ]]; then
        if [[ "$ARCH" == "arm64" ]]; then
            PLATFORM_TAG="macosx_14_0_arm64"
        else
            print_error "macOS Intel (x86_64) wheels are not currently available."
            echo ""
            echo "  Options:"
            echo "    1. Install from source: pip install git+https://github.com/sthenos-security/reach-core.git"
            echo "    2. Contact support: adazzi@sthenosec.com"
            exit 1
        fi
    else
        if [[ "$ARCH" == "aarch64" ]]; then
            PLATFORM_TAG="manylinux_2_28_aarch64"
        else
            PLATFORM_TAG="manylinux_2_28_x86_64"
        fi
    fi
    
    WHEEL_FILE="reachable-${WHEEL_VERSION}-${PY_TAG}-${PY_TAG}-${PLATFORM_TAG}.whl"
    WHEEL_URL="${DIST_URL}/${WHEEL_FILE}"
    
    # Check for curl or wget
    if command -v curl &> /dev/null; then
        DOWNLOADER="curl"
        DOWNLOAD_CMD="curl -fsSL -o"
    elif command -v wget &> /dev/null; then
        DOWNLOADER="wget"
        DOWNLOAD_CMD="wget -q -O"
    else
        print_error "Neither curl nor wget found"
        exit 1
    fi
    
    echo ""
    echo -e "  ${BOLD}System Information${NC}"
    echo -e "  ─────────────────────────────────────────────────────────────"
    print_detail "OS:" "$OS_NAME ($OS_VERSION)"
    print_detail "Architecture:" "$ARCH_NAME"
    print_detail "Python:" "$PY_FULL ($PY_TAG)"
    print_detail "Downloader:" "$DOWNLOADER"
    echo ""
    echo -e "  ${BOLD}Package Information${NC}"
    echo -e "  ─────────────────────────────────────────────────────────────"
    print_detail "Version:" "$VERSION"
    print_detail "Wheel:" "$WHEEL_FILE"
    print_detail "Platform Tag:" "$PLATFORM_TAG"
    echo ""
    echo -e "  ${BOLD}Download Source${NC}"
    echo -e "  ─────────────────────────────────────────────────────────────"
    print_detail "Repository:" "github.com/$DIST_REPO"
    print_detail "URL:" "$WHEEL_URL"
}

# -----------------------------------------------------------------------------
# Download & Install
# -----------------------------------------------------------------------------
download_and_install() {
    print_step "Downloading wheel"
    
    DOWNLOAD_DIR=$(mktemp -d)
    WHEEL_PATH="${DOWNLOAD_DIR}/${WHEEL_FILE}"
    
    print_info "Downloading from $DIST_REPO..."
    
    if [[ "$DOWNLOADER" == "curl" ]]; then
        HTTP_CODE=$(curl -fsSL -w "%{http_code}" -o "$WHEEL_PATH" "$WHEEL_URL" 2>/dev/null) || HTTP_CODE="000"
    else
        if wget -q -O "$WHEEL_PATH" "$WHEEL_URL" 2>/dev/null; then
            HTTP_CODE="200"
        else
            HTTP_CODE="404"
        fi
    fi
    
    if [[ "$HTTP_CODE" != "200" ]] || [[ ! -s "$WHEEL_PATH" ]]; then
        print_error "Download failed (HTTP $HTTP_CODE)"
        echo ""
        echo "  Possible causes:"
        echo "    • Wheel for Python $PY_VERSION may not be available"
        echo "    • Network connectivity issue"
        echo "    • Release v$VERSION not found"
        echo ""
        echo "  Try:"
        echo "    • Check available releases at: github.com/$DIST_REPO/releases"
        echo "    • Contact support: adazzi@sthenosec.com"
        rm -rf "$DOWNLOAD_DIR"
        exit 1
    fi
    
    WHEEL_SIZE=$(du -h "$WHEEL_PATH" | cut -f1)
    print_ok "Downloaded ($WHEEL_SIZE)"
    
    # Uninstall previous version
    if $PYTHON_CMD -m pip show reachable &> /dev/null; then
        print_step "Removing previous installation"
        $PYTHON_CMD -m pip uninstall reachable -y -q
        print_ok "Previous version removed"
    fi
    
    # Install
    print_step "Installing REACHABLE"
    print_info "Running pip install..."
    
    if $PYTHON_CMD -m pip install "$WHEEL_PATH" -q 2>&1; then
        print_ok "Installation complete"
    else
        print_error "Installation failed"
        echo ""
        echo "  Try installing manually:"
        echo "    pip install $WHEEL_PATH"
        rm -rf "$DOWNLOAD_DIR"
        exit 1
    fi
    
    # Cleanup
    rm -rf "$DOWNLOAD_DIR"
}

# -----------------------------------------------------------------------------
# Verify Installation
# -----------------------------------------------------------------------------
verify_installation() {
    print_header "Verification"
    
    # Find reachctl
    if command -v reachctl &> /dev/null; then
        REACHCTL_PATH=$(command -v reachctl)
    else
        # Check common pip install locations
        for path in ~/.local/bin/reachctl /usr/local/bin/reachctl; do
            if [[ -x "$path" ]]; then
                REACHCTL_PATH="$path"
                break
            fi
        done
    fi
    
    if [[ -z "$REACHCTL_PATH" ]]; then
        print_warn "reachctl not in PATH"
        echo ""
        echo "  Add to your PATH:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        echo "  Or run directly:"
        echo "    ~/.local/bin/reachctl --version"
        return
    fi
    
    echo ""
    echo -e "${BOLD}Version:${NC}"
    "$REACHCTL_PATH" version 2>&1 | sed 's/^/  /'
    
    echo ""
    echo -e "${BOLD}Self-test:${NC}"
    if "$REACHCTL_PATH" selftest 2>&1 | tail -20 | sed 's/^/  /'; then
        echo ""
        print_ok "Core installation verified"
    else
        echo ""
        print_warn "Some optional dependencies missing"
        print_info "Run 'reachctl doctor' to check and install them"
    fi
}

# -----------------------------------------------------------------------------
# Print Success Message
# -----------------------------------------------------------------------------
print_success() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}                    ✓ REACHABLE installed successfully!                    ${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Quick Start Commands${NC}"
    echo ""
    echo "    reachctl primer              Show quick-start guide"
    echo "    reachctl doctor              Check/install dependencies"
    echo "    reachctl scan /path/to/repo  Scan a repository"
    echo "    reachctl dashboard           Open results dashboard"
    echo ""
    echo -e "  ${BOLD}Documentation${NC}"
    echo ""
    echo "    https://github.com/sthenos-security/reach-core/docs"
    echo ""
    echo -e "  ${BOLD}Support${NC}"
    echo ""
    echo "    Email: adazzi@sthenosec.com"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    print_header "REACHABLE Installer v${VERSION}"
    
    detect_environment
    download_and_install
    verify_installation
    print_success
}

main "$@"
