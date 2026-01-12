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
VERSION="1.0.0-beta7"
WHEEL_VERSION="1.0.0b7"
DIST_REPO="sthenos-security/reach-dist"

# -----------------------------------------------------------------------------
# GitHub Authentication (called only for remote installs)
# -----------------------------------------------------------------------------
require_github_auth() {
    if [[ -z "$GITHUB_TOKEN" ]]; then
        echo ""
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "\033[0;34m  REACHABLE Private Distribution\033[0m"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo ""
        echo "  A GitHub Personal Access Token is required."
        echo "  Use your own GitHub account token (with 'repo' scope)."
        echo ""
        echo "  Create one at: https://github.com/settings/tokens"
        echo "  Or set: export GITHUB_TOKEN=ghp_xxxx"
        echo ""
        read -sp "  Enter GitHub Token: " GITHUB_TOKEN
        echo ""
        echo ""
    fi

    if [[ -z "$GITHUB_TOKEN" ]]; then
        echo -e "\033[0;31m❌ GitHub token required.\033[0m"
        echo "  Set GITHUB_TOKEN env var or enter when prompted."
        exit 1
    fi

    # Base URL for releases (no token - auth via header)
    DIST_URL="https://github.com/${DIST_REPO}/releases/download/v${VERSION}"
}

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
    print_detail "Release:" "v$VERSION"
}

# -----------------------------------------------------------------------------
# Download & Install
# -----------------------------------------------------------------------------
download_and_install() {
    print_step "Downloading wheel"
    
    DOWNLOAD_DIR=$(mktemp -d)
    WHEEL_PATH="${DOWNLOAD_DIR}/${WHEEL_FILE}"
    
    print_info "Downloading from $DIST_REPO..."
    
    # Use Authorization header for private repo
    if [[ "$DOWNLOADER" == "curl" ]]; then
        HTTP_CODE=$(curl -fsSL \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/octet-stream" \
            -w "%{http_code}" \
            -o "$WHEEL_PATH" \
            "$WHEEL_URL" 2>/dev/null) || HTTP_CODE="000"
    else
        if wget -q --header="Authorization: token ${GITHUB_TOKEN}" -O "$WHEEL_PATH" "$WHEEL_URL" 2>/dev/null; then
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
    
    # Use the common install_local_wheel function
    install_local_wheel "$WHEEL_PATH"
    
    # Cleanup
    rm -rf "$DOWNLOAD_DIR"
}

# -----------------------------------------------------------------------------
# Verify Installation
# -----------------------------------------------------------------------------
verify_installation() {
    print_header "Verification"
    
    # Check the standard install location
    REACHCTL_PATH="$HOME/.reachable/bin/reachctl"
    
    if [[ ! -x "$REACHCTL_PATH" ]]; then
        # Fallback: check if in PATH
        if command -v reachctl &> /dev/null; then
            REACHCTL_PATH=$(command -v reachctl)
        else
            print_warn "reachctl not found"
            echo ""
            echo "  Expected at: ~/.reachable/bin/reachctl"
            echo ""
            echo "  Add to your PATH (add to ~/.zshrc or ~/.bashrc):"
            echo "    export PATH=\"\$HOME/.reachable/bin:\$PATH\""
            return
        fi
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
# Install from local wheel (for testing)
# -----------------------------------------------------------------------------
install_local_wheel() {
    local WHEEL_PATH="$1"
    
    print_step "Installing from local wheel"
    print_info "$WHEEL_PATH"
    
    if [[ ! -f "$WHEEL_PATH" ]]; then
        print_error "Wheel file not found: $WHEEL_PATH"
        exit 1
    fi
    
    WHEEL_SIZE=$(du -h "$WHEEL_PATH" | cut -f1)
    print_ok "Found ($WHEEL_SIZE)"
    
    # Detect Python
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        print_error "Python not found"
        exit 1
    fi
    
    # Create ~/.reachable structure
    INSTALL_DIR="$HOME/.reachable"
    VENV_DIR="$INSTALL_DIR/venv"
    BIN_DIR="$INSTALL_DIR/bin"
    
    print_step "Creating installation directory"
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"
    print_ok "Created $INSTALL_DIR"
    
    # Create venv
    print_step "Creating virtual environment"
    if [[ -d "$VENV_DIR" ]]; then
        print_info "Removing existing venv..."
        rm -rf "$VENV_DIR"
    fi
    $PYTHON_CMD -m venv "$VENV_DIR"
    print_ok "Created venv"
    
    # Install wheel into venv
    print_step "Installing REACHABLE into venv"
    "$VENV_DIR/bin/pip" install --upgrade pip -q
    "$VENV_DIR/bin/pip" install "$WHEEL_PATH" -q
    print_ok "Installed"
    
    # Install required Python tools (semgrep)
    print_step "Installing Python tools"
    "$VENV_DIR/bin/pip" install semgrep -q 2>/dev/null && print_ok "semgrep" || print_warn "semgrep install failed"
    
    # Create isolated guarddog venv (has dependency conflicts with main venv)
    print_step "Installing guarddog (isolated venv)"
    GUARDDOG_VENV="$INSTALL_DIR/guarddog-venv"
    if [[ -d "$GUARDDOG_VENV" ]]; then
        rm -rf "$GUARDDOG_VENV"
    fi
    
    # On macOS, install libgit2 first (required for pygit2, a guarddog dependency)
    if [[ "$(uname)" == "Darwin" ]]; then
        if ! brew list libgit2 &>/dev/null; then
            if command -v brew &>/dev/null; then
                print_info "Installing libgit2 (required for guarddog)..."
                if brew install libgit2 >/dev/null 2>&1; then
                    print_ok "libgit2"
                else
                    print_warn "libgit2 install failed - guarddog may not work"
                fi
            else
                print_warn "Homebrew not found - cannot install libgit2"
                print_info "Install Homebrew: https://brew.sh, then: brew install libgit2"
            fi
        fi
    fi
    
    $PYTHON_CMD -m venv "$GUARDDOG_VENV"
    "$GUARDDOG_VENV/bin/pip" install --upgrade pip -q
    "$GUARDDOG_VENV/bin/pip" install guarddog -q 2>/dev/null && print_ok "guarddog" || print_warn "guarddog install failed"
    
    # Install syft and grype to tools/bin/ (pinned versions, no system dependency)
    print_step "Installing security scanners"
    TOOLS_BIN="$INSTALL_DIR/tools/bin"
    mkdir -p "$TOOLS_BIN"
    
    # Pinned versions
    SYFT_VERSION="1.18.1"
    GRYPE_VERSION="0.84.0"
    
    # Install syft
    if [[ ! -x "$TOOLS_BIN/syft" ]]; then
        print_info "Installing syft v$SYFT_VERSION..."
        if curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b "$TOOLS_BIN" "v$SYFT_VERSION" >/dev/null 2>&1; then
            print_ok "syft $SYFT_VERSION"
        else
            print_warn "syft install failed"
        fi
    else
        print_ok "syft (already installed)"
    fi
    
    # Install grype
    if [[ ! -x "$TOOLS_BIN/grype" ]]; then
        print_info "Installing grype v$GRYPE_VERSION..."
        if curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b "$TOOLS_BIN" "v$GRYPE_VERSION" >/dev/null 2>&1; then
            print_ok "grype $GRYPE_VERSION"
        else
            print_warn "grype install failed"
        fi
    else
        print_ok "grype (already installed)"
    fi
    
    # Pre-populate grype vulnerability database (so first scan is fast)
    print_step "Initializing vulnerability database"
    GRYPE_DB_DIR="$INSTALL_DIR/cache/grype-db"
    mkdir -p "$GRYPE_DB_DIR"
    
    if [[ -x "$TOOLS_BIN/grype" ]]; then
        print_info "Downloading vulnerability database (this may take a minute)..."
        export GRYPE_DB_CACHE_DIR="$GRYPE_DB_DIR"
        if "$TOOLS_BIN/grype" db update >/dev/null 2>&1; then
            print_ok "Grype DB initialized"
            # Record timestamp
            date +%s > "$GRYPE_DB_DIR/.last_update"
        else
            print_warn "DB download failed (will retry on first scan)"
        fi
    fi
    
    # Create symlink in bin/
    print_step "Creating reachctl symlink"
    rm -f "$BIN_DIR/reachctl"
    ln -s "$VENV_DIR/bin/reachctl" "$BIN_DIR/reachctl"
    print_ok "$BIN_DIR/reachctl -> venv/bin/reachctl"
    
    # Update PATH in shell config
    print_step "Configuring PATH"
    SHELL_RC="$HOME/.zshrc"
    [[ -f "$HOME/.bashrc" ]] && [[ ! -f "$HOME/.zshrc" ]] && SHELL_RC="$HOME/.bashrc"
    
    # Remove old PATH entries and add new one
    if [[ -f "$SHELL_RC" ]]; then
        # Remove any existing reachable PATH entries
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' '/REACHABLE/d' "$SHELL_RC" 2>/dev/null || true
            sed -i '' '/\.reachable/d' "$SHELL_RC" 2>/dev/null || true
        else
            sed -i '/REACHABLE/d' "$SHELL_RC" 2>/dev/null || true
            sed -i '/\.reachable/d' "$SHELL_RC" 2>/dev/null || true
        fi
    fi
    
    echo '' >> "$SHELL_RC"
    echo '# REACHABLE - Security Analysis Tool' >> "$SHELL_RC"
    echo 'export PATH="$HOME/.reachable/bin:$PATH"' >> "$SHELL_RC"
    print_ok "Added to $SHELL_RC"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    # Check if local wheel path provided as argument
    if [[ -n "$1" ]] && [[ -f "$1" ]]; then
        print_header "REACHABLE Local Install"
        install_local_wheel "$1"
        verify_installation
        print_success
        return
    fi
    
    # Normal remote installation - requires GitHub auth
    require_github_auth
    print_header "REACHABLE Installer v${VERSION}"
    
    detect_environment
    download_and_install
    verify_installation
    print_success
}

main "$@"
