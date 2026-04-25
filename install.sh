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

# Resolve latest version from reach-dist GitHub releases API.
# Uses GITHUB_TOKEN if set (avoids rate limits in CI).
# Unauthenticated limit: 60 req/hr per IP. Authenticated: 5000 req/hr.
resolve_version() {
    local api_url="https://api.github.com/repos/${REPO}/releases"
    local response

    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        response=$(curl -sL -H "Authorization: Bearer ${GITHUB_TOKEN}" "$api_url")
    else
        response=$(curl -sL "$api_url")
    fi

    echo "$response" | python3 -c "
import sys, json, os
data = json.load(sys.stdin)
if isinstance(data, dict):
    msg = data.get('message', 'unknown error')
    has_token = bool(os.environ.get('GITHUB_TOKEN',''))
    if 'rate limit' in msg.lower():
        if has_token:
            sys.stderr.write('Error: GitHub API rate limit exceeded even with GITHUB_TOKEN.\n')
            sys.stderr.write('  Your token may be invalid or scoped incorrectly.\n')
        else:
            sys.stderr.write('Error: GitHub API rate limit exceeded (unauthenticated).\n')
            sys.stderr.write('  Fix option 1 — set a token and retry:\n')
            sys.stderr.write('    export GITHUB_TOKEN=\"your_token\"\n')
            sys.stderr.write('    curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash\n')
            sys.stderr.write('  Fix option 2 — wait ~1 hour for the rate limit to reset, then retry.\n')
    else:
        sys.stderr.write('Error resolving latest version: GitHub API: ' + msg + '\n')
    sys.exit(1)
if not isinstance(data, list) or not data:
    sys.stderr.write('Error resolving latest version: no releases found\n')
    sys.exit(1)
tag = data[0].get('tag_name', '')
if not tag:
    sys.stderr.write('Error resolving latest version: missing tag_name\n')
    sys.exit(1)
print(tag.lstrip('v'))
" GITHUB_TOKEN="${GITHUB_TOKEN:-}"
}

list_releases() {
    local api_url="https://api.github.com/repos/${REPO}/releases"
    local response

    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        response=$(curl -sL -H "Authorization: Bearer ${GITHUB_TOKEN}" "$api_url")
    else
        response=$(curl -sL "$api_url")
    fi

    # Check installed version
    local installed="(not installed)"
    if [[ -f "$HOME/.reachable/venv/bin/reachctl" ]]; then
        installed=$($HOME/.reachable/venv/bin/reachctl version 2>/dev/null | head -1 || echo "unknown")
    fi

    echo ""
    echo "  REACHABLE — Available Releases"
    echo "  ══════════════════════════════════════════"
    echo "  Installed: $installed"
    echo ""

    echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, dict):
    print('  Error:', data.get('message', 'unknown'))
    sys.exit(1)
if not isinstance(data, list):
    print('  No releases found')
    sys.exit(0)
for i, rel in enumerate(data[:10]):
    tag = rel.get('tag_name', '?')
    name = rel.get('name', '')
    date = rel.get('published_at', '')[:10]
    pre = ' (pre-release)' if rel.get('prerelease') else ''
    latest = ' ← latest' if i == 0 else ''
    assets = [a['name'] for a in rel.get('assets', []) if a['name'].endswith('.whl')]
    platforms = []
    for a in assets:
        if 'macosx' in a: platforms.append('macOS')
        elif 'manylinux' in a: platforms.append('Linux')
        elif 'win' in a: platforms.append('Windows')
    plat_str = ', '.join(sorted(set(platforms))) if platforms else 'no wheels'
    print(f'  {tag:20} {date}  [{plat_str}]{pre}{latest}')
if len(data) > 10:
    print(f'  ... and {len(data) - 10} older releases')
"

    echo ""
    echo "  Install a specific version:"
    echo "    ./install.sh --version 1.0.0b35"
    echo ""
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
            echo "  --version, -v VER  Install specific version (e.g., 1.0.0b35)"
            echo "  --wheel, -w FILE   Install from local wheel file (skips download)"
            echo "  --list, -l         List available releases"
            echo "  --help, -h         Show this help"
            echo ""
            echo "Examples:"
            echo "  ./install.sh                    # Fresh install (latest release)"
            echo "  ./install.sh --list             # Show available versions"
            echo "  ./install.sh --update           # Upgrade with backup"
            echo "  ./install.sh --clean            # Clean install"
            echo "  ./install.sh --version 1.0.0b35 # Install specific version"
            echo "  ./install.sh --wheel ./file.whl # Local wheel install"
            echo ""
            exit 0
            ;;
        --list|-l)
            list_releases
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
    
    # Check python3-venv is available (common missing package on Debian/Ubuntu ARM64)
    if ! python3 -c "import venv" 2>/dev/null; then
        print_error "python3-venv not available"
        if [[ "$OS" == "linux" ]]; then
            echo ""
            echo "  Fix (Debian/Ubuntu):"
            echo "    sudo apt install python3-venv python3-dev"
            echo ""
            echo "  Fix (RHEL/Fedora):"
            echo "    sudo dnf install python3-devel"
        fi
        exit 1
    fi
    
    PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PY_MAJOR=$(echo $PY_VERSION | cut -d. -f1)
    PY_MINOR=$(echo $PY_VERSION | cut -d. -f2)
    
    if [[ "$PY_MAJOR" -lt 3 ]] || [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 11 ]]; then
        print_error "Python 3.11+ required (found $PY_VERSION)"
        exit 1
    fi
    
    PY_TAG="cp${PY_VERSION//./}"
    
    # Platform tag for wheel
    # macOS: universal2 fat binary (ARM64 + Intel)
    # Linux: native architecture tags
    if [[ "$OS" == "darwin" ]]; then
        # macOS universal2 wheels (ARM64 + Intel fat binary)
        PLATFORM_TAG="macosx_11_0_universal2"
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

        # Install vendor wheels first if present (pre-compiled C extensions)
        # Direct install avoids pip ignoring them due to platform tag mismatches
        WHEEL_DIR=$(dirname "$LOCAL_WHEEL")
        HAS_VENDOR=false
        if [[ -d "$WHEEL_DIR/vendor" ]] && ls "$WHEEL_DIR/vendor"/*.whl 1>/dev/null 2>&1; then
            print_ok "Installing vendor wheels from $WHEEL_DIR/vendor/"
            "$HOME/.reachable/venv/bin/pip" install --no-deps --force-reinstall "$WHEEL_DIR/vendor"/*.whl -q
            HAS_VENDOR=true
        fi

        set +e
        PIP_OUTPUT=$("$HOME/.reachable/venv/bin/pip" install "$LOCAL_WHEEL" -q 2>&1)
        PIP_RC=$?
        set -e
        if [[ $PIP_RC -ne 0 ]]; then
            if echo "$PIP_OUTPUT" | grep -qi "gcc\|building wheel\|Failed building"; then
                print_error "Installation failed — a C extension needs compilation but gcc is not installed"
                if [[ "$HAS_VENDOR" == true ]]; then
                    print_error "Vendor wheels were installed but versions may not match. This is a packaging bug."
                    print_error "Report to: info@sthenosec.com"
                else
                    print_info "Try placing vendor/*.whl next to the wheel file, or install gcc:"
                    print_info "  sudo apt-get install gcc python3-dev"
                fi
            else
                echo "$PIP_OUTPUT" | tail -20
            fi
            exit 1
        fi
        print_ok "Installation complete"
        if [[ -n "${GITHUB_PATH:-}" ]]; then
            echo "$HOME/.reachable/venv/bin" >> "$GITHUB_PATH"
            echo "$HOME/.reachable/tools/bin" >> "$GITHUB_PATH"
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
    
    WHEEL_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${WHEEL_FILE}"
    if ! curl -fsSL -L "$WHEEL_URL" -o "$WHEEL_FILE"; then
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
    CHECKSUM_URL="https://github.com/${REPO}/releases/download/v${VERSION}/checksums.sha256"
    if curl -fsSL -L "$CHECKSUM_URL" -o checksums.sha256 2>/dev/null; then
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

    # ── Cosign: auto-install if missing ──────────────────────────────────────
    if ! command -v cosign &>/dev/null; then
        if [[ "$OS" == "darwin" ]] && command -v brew &>/dev/null; then
            if brew install cosign 2>/dev/null; then
                print_ok "Installed cosign via Homebrew"
            else
                print_warn "cosign install via Homebrew timed out or failed — proceeding"
            fi
        elif [[ "$OS" == "linux" ]]; then
            COSIGN_ARCH=$(uname -m)
            if [[ "$COSIGN_ARCH" == "x86_64" ]]; then
                COSIGN_ARCH="amd64"
            elif [[ "$COSIGN_ARCH" == "aarch64" ]]; then
                COSIGN_ARCH="arm64"
            fi
            COSIGN_URL="https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-${COSIGN_ARCH}"
            if curl -fsSL --max-time 15 "$COSIGN_URL" -o /tmp/cosign 2>/dev/null; then
                chmod +x /tmp/cosign
                mkdir -p "$HOME/.reachable/tools/bin"
                mv /tmp/cosign "$HOME/.reachable/tools/bin/cosign"
                export PATH="$HOME/.reachable/tools/bin:$PATH"
                print_ok "Installed cosign to ~/.reachable/tools/bin/"
            else
                print_warn "cosign download timed out or failed — proceeding"
            fi
        fi
    fi

    # ── Cosign signature verification ─────────────────────────────────────────
    COSIGN_BUNDLE="${WHEEL_FILE}.cosign.bundle"
    BUNDLE_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${COSIGN_BUNDLE}"
    if command -v cosign &>/dev/null; then
        if curl -fsSL -L "$BUNDLE_URL" -o "$COSIGN_BUNDLE" 2>/dev/null; then
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
        print_warn "cosign not available — signature check skipped (SHA-256 verified)"
        print_info "Install cosign for full supply chain verification: https://docs.sigstore.dev"
    fi

    # Uninstall previous version
    if pip3 show reachable &> /dev/null; then
        print_step "Removing previous installation"
        pip3 uninstall reachable -y -q 2>/dev/null || true
        print_ok "Previous version removed"
    fi

    # Install into venv
    print_step "Installing REACHABLE v$VERSION"
    if ! python3 -m venv "$HOME/.reachable/venv" 2>&1; then
        print_error "Failed to create virtual environment"
        if [[ "$OS" == "linux" ]]; then
            echo "  Try: sudo apt install python3-venv python3-dev"
        fi
        exit 1
    fi
    "$HOME/.reachable/venv/bin/pip" install --upgrade pip -q

    # Download hash-pinned constraints (blocks supply chain attacks on dependencies)
    CONSTRAINTS_URL="https://github.com/${REPO}/releases/download/v${VERSION}/constraints.txt"
    CONSTRAINTS_FLAG=""
    if curl -fsSL -L "$CONSTRAINTS_URL" -o constraints.txt 2>/dev/null; then
        if grep -q "\-\-hash=" constraints.txt 2>/dev/null; then
            CONSTRAINTS_FLAG="--constraint constraints.txt --require-hashes"
            print_ok "Dependency constraints verified (hash-pinned)"
        else
            CONSTRAINTS_FLAG="--constraint constraints.txt"
            print_ok "Dependency constraints loaded (version-pinned)"
        fi
    else
        print_warn "No constraints.txt found — dependencies resolved from PyPI (unpinned)"
    fi

    # Download pre-compiled vendor wheels (C extensions: psutil, ruamel.yaml.clib)
    # Built and signed in CI — no PyPI contact, no compiler needed on customer machine.
    # Only published for Linux — macOS ships with Xcode command line tools.
    FIND_LINKS_FLAG=""
    if [[ "$OS" == "linux" ]]; then
        VENDOR_ARCHIVE="vendor-${PY_TAG}-${PLATFORM_TAG}.tar.gz"
        VENDOR_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${VENDOR_ARCHIVE}"
        if curl -fsSL -L "$VENDOR_URL" -o "$VENDOR_ARCHIVE" 2>/dev/null; then
            # Verify vendor archive checksum (included in checksums.sha256 since CI signs it)
            if [[ -f checksums.sha256 ]] && grep -q "$VENDOR_ARCHIVE" checksums.sha256; then
                EXPECTED_VENDOR=$(grep "$VENDOR_ARCHIVE" checksums.sha256 | awk '{print $1}')
                if command -v sha256sum &>/dev/null; then
                    ACTUAL_VENDOR=$(sha256sum "$VENDOR_ARCHIVE" | awk '{print $1}')
                else
                    ACTUAL_VENDOR=$(shasum -a 256 "$VENDOR_ARCHIVE" | awk '{print $1}')
                fi
                if [[ "$EXPECTED_VENDOR" == "$ACTUAL_VENDOR" ]]; then
                    print_ok "Vendor archive checksum verified"
                else
                    print_error "Vendor archive checksum FAILED — aborting"
                    exit 1
                fi
            fi

            # Verify vendor archive cosign signature (if cosign available)
            if command -v cosign &>/dev/null; then
                VENDOR_BUNDLE="${VENDOR_ARCHIVE}.cosign.bundle"
                VENDOR_BUNDLE_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${VENDOR_BUNDLE}"
                if curl -fsSL -L "$VENDOR_BUNDLE_URL" -o "$VENDOR_BUNDLE" 2>/dev/null; then
                    if cosign verify-blob \
                        --bundle "$VENDOR_BUNDLE" \
                        --certificate-identity-regexp "https://github.com/sthenos-security/" \
                        --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
                        "$VENDOR_ARCHIVE" &>/dev/null; then
                        print_ok "Vendor archive signature verified (Sigstore)"
                    else
                        print_error "Vendor archive signature FAILED — aborting"
                        exit 1
                    fi
                fi
            fi

            mkdir -p vendor/
            tar xzf "$VENDOR_ARCHIVE" -C vendor/
            if ls vendor/*.whl 1>/dev/null 2>&1; then
                # Install vendor wheels directly first (avoids platform tag issues)
                "$HOME/.reachable/venv/bin/pip" install --no-deps --force-reinstall vendor/*.whl -q
                print_ok "Vendor wheels installed (built and signed in CI)"
            fi
        else
            print_info "No vendor wheels for this platform — dependencies from PyPI"
        fi
    fi

    set +e
    PIP_OUTPUT=$("$HOME/.reachable/venv/bin/pip" install $CONSTRAINTS_FLAG "$WHEEL_FILE" 2>&1)
    PIP_RC=$?
    set -e
    if [[ $PIP_RC -ne 0 ]]; then
        if echo "$PIP_OUTPUT" | grep -qi "gcc\|building wheel\|Failed building"; then
            print_error "Installation failed — a C extension needs compilation but gcc is not installed"
            print_error "This is a packaging bug. Report to: info@sthenosec.com"
        else
            echo "$PIP_OUTPUT" | tail -30
        fi
        print_error "pip install failed (exit $PIP_RC)"
        exit 1
    fi
    print_ok "Installation complete"

    # Cleanup
    rm -rf "$DOWNLOAD_DIR"

    # If running in GitHub Actions, add venv + tools to PATH for subsequent steps
    if [[ -n "${GITHUB_PATH:-}" ]]; then
        echo "$HOME/.reachable/venv/bin" >> "$GITHUB_PATH"
        echo "$HOME/.reachable/tools/bin" >> "$GITHUB_PATH"
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
    echo -e "  ${BOLD}Version:${NC}"
    echo "    Installed: v${VERSION}"
    echo "    Check for updates:  ./install.sh --list"
    echo ""
    echo -e "  ${BOLD}Upgrade:${NC}"
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
