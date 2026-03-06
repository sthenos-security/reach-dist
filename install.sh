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
#  Installer (GitHub CLI Edition)
#  Copyright © 2026 Sthenos Security. All rights reserved.
#
#  Usage:
#
#    # Standard install (no auth required)
#    curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash
#
#    # Local wheel install
#    ./install.sh --wheel /path/to/reachable-<version>-<platform>.whl
#
#  Other options:
#    ./install.sh --update          # Upgrade with backup
#    ./install.sh --clean           # Clean install (removes data)
#    ./install.sh --version <ver>   # Install specific version
#
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
REPO="sthenos-security/reach-dist"

# Resolve latest version from reach-dist GitHub releases API
resolve_version() {
    local response
    response=$(curl -sL "https://api.github.com/repos/${REPO}/releases")
    echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not isinstance(data, list) or not data:
    sys.stderr.write('Error resolving latest version: no releases found\n')
    sys.exit(1)
tag = data[0].get('tag_name', '')
if not tag:
    sys.stderr.write('Error resolving latest version: missing tag_name\n')
    sys.exit(1)
print(tag.lstrip('v'))
"
}

VERSION=""
WHEEL_VERSION=""

# -----------------------------------------------------------------------------
# Parse Arguments
# -----------------------------------------------------------------------------
UPDATE_MODE=false
CUSTOM_VERSION=""
CLEAN_DATA=false
LOCAL_WHEEL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --update|-u)
            UPDATE_MODE=true
            shift
            ;;
        --version|-v)
            CUSTOM_VERSION="$2"
            shift 2
            ;;
        --clean)
            CLEAN_DATA=true
            shift
            ;;
        --wheel|-w)
            LOCAL_WHEEL="$2"
            shift 2
            ;;
        --help|-h)
            echo "REACHABLE Installer"
            echo ""
            echo "Usage:"
            echo "  ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --update, -u       Upgrade existing installation (backs up data)"
            echo "  --clean            Remove existing data before install"
            echo "  --version, -v VER  Install specific version (e.g., 1.0.0-beta10)"
            echo "  --wheel, -w FILE   Install from local wheel file (skips download)"
            echo "  --help, -h         Show this help"
            echo ""
            echo "Examples:"
            echo "  ./install.sh                    # Fresh install (prompts for auth)"
            echo "  ./install.sh --update           # Upgrade with backup"
            echo "  ./install.sh --clean            # Clean install"
            echo "  ./install.sh --wheel ./file.whl # Local wheel install"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage"
            exit 1
            ;;
    esac
done

# Apply custom version or resolve latest
if [[ -n "$CUSTOM_VERSION" ]]; then
    VERSION="$CUSTOM_VERSION"
else
    VERSION=$(resolve_version)
    if [[ -z "$VERSION" ]]; then
        echo "Error: could not resolve latest version from ${REPO}"
        exit 1
    fi
fi
WHEEL_VERSION="$VERSION"

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

# -----------------------------------------------------------------------------
# Detect Environment
# -----------------------------------------------------------------------------
detect_environment() {
    print_step "Detecting environment"
    
    # OS
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$OS" in
        darwin) OS_NAME="macOS" ;;
        linux)  OS_NAME="Linux" ;;
        *)      print_error "Unsupported OS: $OS"; exit 1 ;;
    esac
    
    # Architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  ARCH_NAME="x86_64" ;;
        aarch64) ARCH_NAME="ARM64" ;;
        arm64)   ARCH_NAME="ARM64" ;;
        *)       print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    # Python version
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 not found"
        exit 1
    fi
    
    PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PY_MAJOR=$(echo $PY_VERSION | cut -d. -f1)
    PY_MINOR=$(echo $PY_VERSION | cut -d. -f2)
    
    if [[ "$PY_MAJOR" -lt 3 ]] || [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 10 ]]; then
        print_error "Python 3.10+ required (found $PY_VERSION)"
        exit 1
    fi
    
    PY_TAG="cp${PY_VERSION//./}"
    
    # Platform tag for wheel
    # Note: macOS uses universal2 (supports both Intel and ARM)
    # Linux uses simple linux_* tags (not manylinux)
    if [[ "$OS" == "darwin" ]]; then
        # macOS universal2 wheels - platform varies by Python version
        if [[ "$PY_MINOR" -ge 14 ]]; then
            PLATFORM_TAG="macosx_10_15_universal2"
        elif [[ "$PY_MINOR" -ge 12 ]]; then
            PLATFORM_TAG="macosx_10_13_universal2"
        else
            PLATFORM_TAG="macosx_10_9_universal2"
        fi
    else
        # Linux
        if [[ "$ARCH" == "aarch64" ]]; then
            PLATFORM_TAG="linux_aarch64"
        else
            PLATFORM_TAG="linux_x86_64"
        fi
    fi
    
    WHEEL_FILE="reachable-${WHEEL_VERSION}-${PY_TAG}-${PY_TAG}-${PLATFORM_TAG}.whl"
    
    print_ok "OS:           $OS_NAME $ARCH_NAME"
    print_ok "Python:       $PY_VERSION ($PY_TAG)"
    print_ok "Wheel:        $WHEEL_FILE"
}

# -----------------------------------------------------------------------------
# Setup GitHub CLI
# -----------------------------------------------------------------------------
# No GitHub CLI or auth needed — reach-dist is public

# -----------------------------------------------------------------------------
# Handle Existing Installation
# -----------------------------------------------------------------------------
handle_existing_install() {
    INSTALLED_VERSION=""
    BACKUP_DIR=""
    
    if pip3 show reachable &> /dev/null; then
        INSTALLED_VERSION=$(pip3 show reachable | grep "^Version:" | awk '{print $2}')
        print_step "Existing installation detected"
        print_info "Installed version: $INSTALLED_VERSION"
        print_info "Target version:    $WHEEL_VERSION"
        
        if [[ "$UPDATE_MODE" == true ]]; then
            # Backup existing data
            if [[ -d "$HOME/.reachable" ]]; then
                BACKUP_DIR="$HOME/.reachable.backup.$(date +%Y%m%d-%H%M%S)"
                print_step "Backing up existing data"
                cp -r "$HOME/.reachable" "$BACKUP_DIR" 2>/dev/null || true
                print_ok "Backup created: $BACKUP_DIR"
            fi
        elif [[ "$CLEAN_DATA" == false ]]; then
            # Fresh install mode without --clean - warn user
            echo ""
            print_warn "REACHABLE is already installed (v$INSTALLED_VERSION)"
            echo ""
            echo -e "  ${BOLD}Options:${NC}"
            echo "    • To upgrade (keeps data):    curl ... | bash -s -- --update"
            echo "    • To clean install (beta):    curl ... | bash -s -- --clean"
            echo ""
            echo -e "  ${YELLOW}⚠ Beta Notice:${NC} During beta, we recommend --clean to avoid"
            echo "    database compatibility issues between versions."
            echo ""
            
            read -p "  Continue with upgrade (keeps data)? [y/N] " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Installation cancelled"
                exit 0
            fi
            UPDATE_MODE=true
        fi
    fi
    
    # Handle --clean flag
    if [[ "$CLEAN_DATA" == true ]] && [[ -d "$HOME/.reachable" ]]; then
        print_step "Removing existing data (--clean)"
        rm -rf "$HOME/.reachable"
        print_ok "Removed ~/.reachable"
    fi
}

# -----------------------------------------------------------------------------
# Download & Install
# -----------------------------------------------------------------------------
download_and_install() {
    # If local wheel provided, use it directly
    if [[ -n "$LOCAL_WHEEL" ]]; then
        print_step "Installing from local wheel"
        
        if [[ ! -f "$LOCAL_WHEEL" ]]; then
            print_error "Wheel file not found: $LOCAL_WHEEL"
            exit 1
        fi
        
        print_info "File: $LOCAL_WHEEL"
        
        # Uninstall previous version
        if pip3 show reachable &> /dev/null; then
            print_step "Removing previous installation"
            pip3 uninstall reachable -y -q 2>/dev/null || true
            print_ok "Previous version removed"
        fi
        
        # Install into venv
        print_step "Installing REACHABLE"
        python3 -m venv "$HOME/.reachable/venv"
        "$HOME/.reachable/venv/bin/pip" install --upgrade pip -q
        "$HOME/.reachable/venv/bin/pip" install "$LOCAL_WHEEL" -q
        print_ok "Installation complete"
        if [[ -n "${GITHUB_PATH:-}" ]]; then
            echo "$HOME/.reachable/venv/bin" >> "$GITHUB_PATH"
        fi
        return
    fi
    
    # Remote install - download from GitHub
    print_step "Downloading wheel"
    
    DOWNLOAD_DIR=$(mktemp -d)
    cd "$DOWNLOAD_DIR"
    
    print_info "Repository: github.com/$REPO"
    print_info "Release:    v$VERSION"
    print_info "File:       $WHEEL_FILE"
    
    WHEEL_URL="https://raw.githubusercontent.com/${REPO}/main/wheels/v${VERSION}/${WHEEL_FILE}"
    if ! curl -fsSL "$WHEEL_URL" -o "$WHEEL_FILE"; then
        print_error "Download failed"
        echo ""
        echo "  URL: $WHEEL_URL"
        echo "  Possible causes:"
        echo "    • Version v$VERSION not yet available"
        echo "    • Wheel for Python $PY_VERSION / $PLATFORM_TAG not available"
        echo ""
        echo "  Contact: info@sthenosec.com"
        exit 1
    fi
    
    print_ok "Downloaded successfully"

    # ── SHA-256 checksum verification ────────────────────────────────────────
    print_step "Verifying integrity"
    CHECKSUM_URL="https://raw.githubusercontent.com/${REPO}/main/wheels/v${VERSION}/checksums.sha256"
    if curl -fsSL "$CHECKSUM_URL" -o checksums.sha256 2>/dev/null; then
        if grep -q "$WHEEL_FILE" checksums.sha256; then
            EXPECTED=$(grep "$WHEEL_FILE" checksums.sha256 | awk '{print $1}')
            if command -v sha256sum &>/dev/null; then
                ACTUAL=$(sha256sum "$WHEEL_FILE" | awk '{print $1}')
            else
                ACTUAL=$(shasum -a 256 "$WHEEL_FILE" | awk '{print $1}')
            fi
            if [[ "$EXPECTED" == "$ACTUAL" ]]; then
                print_ok "SHA-256 checksum verified"
            else
                print_error "SHA-256 checksum FAILED — aborting"
                exit 1
            fi
        else
            print_warn "Checksum entry not found — skipping SHA-256 check"
        fi
    else
        print_warn "Could not fetch checksums — skipping SHA-256 check"
    fi

    # ── Cosign signature verification (optional, skipped if cosign not installed) ──
    COSIGN_BUNDLE="${WHEEL_FILE}.cosign.bundle"
    BUNDLE_URL="https://raw.githubusercontent.com/${REPO}/main/wheels/v${VERSION}/${COSIGN_BUNDLE}"
    if command -v cosign &>/dev/null; then
        if curl -fsSL "$BUNDLE_URL" -o "$COSIGN_BUNDLE" 2>/dev/null; then
            if cosign verify-blob \
                --bundle "$COSIGN_BUNDLE" \
                --certificate-identity-regexp "https://github.com/sthenos-security/" \
                --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
                "$WHEEL_FILE" &>/dev/null; then
                print_ok "Cosign signature verified (Sigstore)"
            else
                print_error "Cosign signature verification FAILED — aborting"
                exit 1
            fi
        else
            print_warn "Could not fetch cosign bundle — skipping signature check"
        fi
    else
        print_info "cosign not installed — skipping signature check (SHA-256 verified)"
    fi

    # Uninstall previous version
    if pip3 show reachable &> /dev/null; then
        print_step "Removing previous installation"
        pip3 uninstall reachable -y -q 2>/dev/null || true
        print_ok "Previous version removed"
    fi

    # Install into venv
    print_step "Installing REACHABLE v$VERSION"
    python3 -m venv "$HOME/.reachable/venv"
    "$HOME/.reachable/venv/bin/pip" install --upgrade pip -q
    "$HOME/.reachable/venv/bin/pip" install "$WHEEL_FILE" -q
    print_ok "Installation complete"

    # Cleanup
    rm -rf "$DOWNLOAD_DIR"

    # If running in GitHub Actions, add venv to PATH for subsequent steps
    if [[ -n "${GITHUB_PATH:-}" ]]; then
        echo "$HOME/.reachable/venv/bin" >> "$GITHUB_PATH"
    fi
}

# -----------------------------------------------------------------------------
# Verify Installation
# -----------------------------------------------------------------------------
verify_installation() {
    print_header "Verification"
    
    VENV_REACHCTL="$HOME/.reachable/venv/bin/reachctl"

    echo ""
    echo -e "${BOLD}Doctor:${NC}"
    "$VENV_REACHCTL" doctor --full 2>&1 | sed 's/^/  /'

    echo ""
    echo -e "${BOLD}Self-test:${NC}"
    if "$VENV_REACHCTL" selftest 2>&1 | sed 's/^/  /'; then
        print_ok "All checks passed"
    else
        print_warn "Some tests failed (non-fatal)"
    fi

    echo ""
    echo -e "${BOLD}Version:${NC}"
    "$VENV_REACHCTL" version 2>&1 | sed 's/^/  /'
}

# -----------------------------------------------------------------------------
# Print Success Message
# -----------------------------------------------------------------------------
print_success() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [[ "$UPDATE_MODE" == true ]]; then
        echo -e "${GREEN}  ✓ REACHABLE upgraded successfully!${NC}"
    elif [[ "$CLEAN_DATA" == true ]]; then
        echo -e "${GREEN}  ✓ REACHABLE installed successfully! (clean install)${NC}"
    else
        echo -e "${GREEN}  ✓ REACHABLE installed successfully!${NC}"
    fi
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Quick Start:${NC}"
    echo ""
    echo "    reachctl primer          # View quick-start guide"
    echo "    reachctl doctor          # Check/install dependencies"
    echo "    reachctl scan /path      # Scan a repository"
    echo ""
    echo -e "  ${BOLD}Add to PATH:${NC}"
    echo "    export PATH=\"\$HOME/.reachable/venv/bin:\$PATH\""
    echo "    # Add to ~/.zshrc or ~/.bashrc to make permanent"
    echo ""
    if [[ -n "$BACKUP_DIR" ]]; then
        echo -e "  ${BOLD}Note:${NC} Previous data backed up to:"
        echo "    $BACKUP_DIR"
        echo ""
    fi
    echo -e "  ${BOLD}Future Upgrades:${NC}"
    echo "    curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --update"
    echo ""
    echo -e "  ${BOLD}Support:${NC} info@sthenosec.com"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    if [[ -n "$LOCAL_WHEEL" ]]; then
        print_header "REACHABLE Local Install"
    elif [[ "$UPDATE_MODE" == true ]]; then
        print_header "REACHABLE Upgrade v${VERSION}"
    elif [[ "$CLEAN_DATA" == true ]]; then
        print_header "REACHABLE Clean Install v${VERSION}"
    else
        print_header "REACHABLE Installer v${VERSION}"
    fi
    
    detect_environment
    handle_existing_install
    download_and_install
    verify_installation
    print_success
}

main "$@"
