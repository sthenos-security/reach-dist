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
#    curl -fsSL https://sthenosec.com/download/install.sh | bash
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

set -euo pipefail

INSTALLER_START_PWD="${PWD:-$(pwd -P 2>/dev/null || pwd)}"
REACHABLE_TMP_ROOT="$HOME/.reachable/tmp"
PUBLIC_INSTALL_URL="https://sthenosec.com/download/install.sh"

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
        # F-006a: pass token via --config stdin, not CLI args (CWE-214)
        response=$(printf 'header = "Authorization: Bearer %s"\n' "${GITHUB_TOKEN}" \
            | curl -sL --config - "$api_url")
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
            sys.stderr.write('    curl -fsSL https://sthenosec.com/download/install.sh | bash\n')
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
        # F-006a: pass token via --config stdin, not CLI args (CWE-214)
        response=$(printf 'header = "Authorization: Bearer %s"\n' "${GITHUB_TOKEN}" \
            | curl -sL --config - "$api_url")
    else
        response=$(curl -sL "$api_url")
    fi

    # Check installed version
    local installed="(not installed)"
    if [[ -f "$HOME/.reachable/venv/bin/reachctl" ]]; then
        installed=$("$HOME/.reachable/venv/bin/reachctl" version 2>/dev/null | head -1 || echo "unknown")
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
    echo "    curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --version 1.0.0b35"
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
ENABLE_VIBE_CODING=false
VIBE_WORKSPACE=""
VIBE_SKIP_BASELINE=false
VIBE_AGENTS=()

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
        --vibe-coding|--vibe)
            ENABLE_VIBE_CODING=true
            shift
            ;;
        --agent)
            ENABLE_VIBE_CODING=true
            VIBE_AGENTS+=("$2")
            shift 2
            ;;
        --repo|--workspace)
            VIBE_WORKSPACE="$2"
            shift 2
            ;;
        --no-auto-vibe|--skip-vibe-baseline)
            ENABLE_VIBE_CODING=true
            VIBE_SKIP_BASELINE=true
            shift
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
            echo "  --vibe-coding      Run bundled reach-vibe setup after install"
            echo "  --vibe             Alias for --vibe-coding"
            echo "  --agent NAME       Restrict reach-vibe wiring to a specific agent"
            echo "  --repo DIR         Repo root for reach-vibe setup (defaults to current repo)"
            echo "  --no-auto-vibe     Skip the initial reach-vibe baseline scan"
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
            echo "  ./install.sh --vibe                         # Install + wire detected coding agents"
            echo "  ./install.sh --vibe --agent codex          # Install + wire Codex only"
            echo "  ./install.sh --vibe --no-auto-vibe         # Install + defer first vibe scan"
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
# --wheel mode doesn't need a version (extracted from wheel filename)
if [[ -n "$LOCAL_WHEEL" ]]; then
    VERSION="local"
    WHEEL_VERSION="local"
elif [[ -n "$CUSTOM_VERSION" ]]; then
    VERSION="$CUSTOM_VERSION"
    WHEEL_VERSION="$VERSION"
else
    VERSION=$(resolve_version)
    if [[ -z "$VERSION" ]]; then
        echo "Error: could not resolve latest version from ${REPO}"
        exit 1
    fi
    WHEEL_VERSION="$VERSION"
fi

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

# Retag vendor wheels from native linux_* platform tags to manylinux_2_17_*
# so pip's --find-links resolver recognises them.  CI builds produce wheels
# with bare linux_aarch64 / linux_x86_64 tags because they're built on the
# target platform without auditwheel.  pip's resolver only matches manylinux_*
# tags when selecting wheels from a --find-links directory.
_retag_vendor_wheels() {
    local vendor_dir="$1"
    for whl in "$vendor_dir"/*.whl; do
        local base
        base=$(basename "$whl")
        local new="$base"
        new="${new//linux_aarch64/manylinux_2_17_aarch64.manylinux2014_aarch64}"
        new="${new//linux_x86_64/manylinux_2_17_x86_64.manylinux2014_x86_64}"
        if [ "$base" != "$new" ]; then
            mv "$vendor_dir/$base" "$vendor_dir/$new"
        fi
    done
}

# Emit --only-binary flags for every package found in the vendor directory.
# This tells pip "never build these from source" — if the vendor wheel isn't
# compatible, pip fails fast instead of trying to compile C code without gcc.
# Outputs nothing if the vendor dir is empty or missing.
_vendor_only_binary_flags() {
    local vendor_dir="$1"
    if [ ! -d "$vendor_dir" ]; then
        return
    fi
    local whl_count
    whl_count=$(find "$vendor_dir" -maxdepth 1 -name "*.whl" 2>/dev/null | wc -l)
    if [ "$whl_count" -eq 0 ]; then
        return
    fi
    local flags=""
    for whl in "$vendor_dir"/*.whl; do
        # Extract package name from wheel filename (name-version-...)
        local pkg
        pkg=$(basename "$whl" | sed 's/-[0-9].*//' | tr '_' '-')
        # Deduplicate: only add if not already in flags
        case "$flags" in
            *"$pkg"*) ;;
            *) flags="$flags --only-binary $pkg" ;;
        esac
    done
    echo "$flags"
}

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

PATH_CONFIG_TARGET=""
PATH_CONFIG_STATUS="unchanged"

_shell_rc_path() {
    local shell_name
    shell_name=$(basename "${SHELL:-}")
    case "$shell_name" in
        zsh)
            echo "$HOME/.zshrc"
            ;;
        bash)
            if [[ -f "$HOME/.bashrc" || ! -f "$HOME/.bash_profile" ]]; then
                echo "$HOME/.bashrc"
            else
                echo "$HOME/.bash_profile"
            fi
            ;;
        *)
            echo "$HOME/.profile"
            ;;
    esac
}

configure_shell_path() {
    local reach_path="$HOME/.reachable/venv/bin"
    local rc_file

    case ":$PATH:" in
        *":$reach_path:"*) ;;
        *) export PATH="$reach_path:$PATH" ;;
    esac

    rc_file="$(_shell_rc_path)"
    PATH_CONFIG_TARGET="$rc_file"
    mkdir -p "$(dirname "$rc_file")"
    touch "$rc_file"

    if grep -Fq "$reach_path" "$rc_file" 2>/dev/null; then
        PATH_CONFIG_STATUS="already-configured"
        return
    fi

    {
        echo ""
        echo "# Added by REACHABLE installer"
        echo "export PATH=\"\$HOME/.reachable/venv/bin:\$PATH\""
    } >> "$rc_file"
    PATH_CONFIG_STATUS="updated"
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
    PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
    
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

                # Clear AI verdict caches on upgrade — Enzo prompts and AI
                # discovery prompts can change between versions; stale entries
                # served by the fast-path cache lookup would mask new behavior
                # (b76b regression: 100% cache hit served pre-dp_ctx verdicts).
                # ai-cache.db is also auto-wiped on AI_CACHE_SCHEMA_VERSION_INT
                # bumps inside init_schema(); this is belt-and-suspenders and
                # additionally handles ai-discovery.json which has no
                # schema-version mechanism. Backup above preserves originals.
                print_step "Clearing AI verdict caches (prompts may have changed)"
                find "$HOME/.reachable/scans" -name "ai-cache.db" -delete 2>/dev/null || true
                find "$HOME/.reachable/scans" -name "ai-discovery.json" -delete 2>/dev/null || true
                print_ok "AI caches cleared — next scan will rebuild fresh verdicts"
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
            
            # F-008: read from /dev/tty so prompts work inside curl | bash (CWE-676)
            read -p "  Continue with upgrade (keeps data)? [y/N] " -n 1 -r < /dev/tty
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

        # Install vendor wheels if present (pre-compiled C extensions).
        # These are C packages (ruamel.yaml.clib, psutil, yara-python) built in CI
        # for this exact Python version + platform.
        #
        # Strategy: rename vendor wheels from linux_* tags to manylinux_2_17_*
        # so pip's --find-links resolver recognises them.  Then install the main
        # wheel with --find-links pointing at the vendor dir.  pip resolves
        # vendor deps from the local directory and never attempts a source build.
        WHEEL_DIR=$(dirname "$LOCAL_WHEEL")
        HAS_VENDOR=false
        VENDOR_FIND_LINKS=""
        if [[ -d "$WHEEL_DIR/vendor" ]] && ls "$WHEEL_DIR/vendor"/*.whl 1>/dev/null 2>&1; then
            print_ok "Preparing vendor wheels from $WHEEL_DIR/vendor/"
            _retag_vendor_wheels "$WHEEL_DIR/vendor"
            VENDOR_FIND_LINKS="--find-links $WHEEL_DIR/vendor/"
            HAS_VENDOR=true
        fi

        # ── Pre-install vendor wheels ──────────────────────────────────────
        # Vendor wheels contain C extensions (yara-python, psutil, ruamel-yaml-clib)
        # built in CI.  Some are deps of guarddog, not reachable — so --find-links
        # alone won't install them.  Install ALL vendor wheels explicitly first.
        if [[ "$HAS_VENDOR" == true ]]; then
            # F-009b: vendor wheel install failure is meaningful — do not swallow (CWE-755)
            if ! "$HOME/.reachable/venv/bin/pip" install --no-deps --force-reinstall "$WHEEL_DIR/vendor"/*.whl -q 2>&1; then
                print_warn "Some vendor wheels failed to install — main install may still succeed"
            fi
        fi

        # Install the main wheel.  --find-links lets pip resolve any remaining
        # dependencies; --only-binary for each vendor package prevents fallback
        # to source builds when no compiler is present.
        set +e
        # shellcheck disable=SC2086,SC2046 -- intentional word-splitting for optional pip flags
        PIP_OUTPUT=$("$HOME/.reachable/venv/bin/pip" install \
            $VENDOR_FIND_LINKS \
            $(_vendor_only_binary_flags "$WHEEL_DIR/vendor") \
            "$LOCAL_WHEEL" 2>&1)
        PIP_RC=$?
        set -e
        if [[ $PIP_RC -ne 0 ]]; then
            print_error "pip install failed (exit $PIP_RC)"
            echo "$PIP_OUTPUT" | tail -30
            if [[ "$HAS_VENDOR" == true ]]; then
                echo ""
                print_error "Vendor wheels were pre-installed but pip still failed."
                print_error "Report to: info@sthenosec.com"
            fi
            exit 1
        fi
        print_ok "Installation complete"
        # Write venv-initialized stamp for local wheel path
        if [[ "$HAS_VENDOR" == true ]]; then
            STAMP="$HOME/.reachable/venv/.vendor-stamp"
            : > "$STAMP"
            for whl in "$WHEEL_DIR/vendor"/*.whl; do
                [[ -f "$whl" ]] || continue
                pkg=$(basename "$whl" | sed 's/-[0-9].*//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
                echo "$pkg" >> "$STAMP"
            done
        fi
        if [[ -n "${GITHUB_PATH:-}" ]]; then
            # F-009c: idempotent — don't double-append on re-runs (CWE-426)
            grep -qxF "$HOME/.reachable/venv/bin" "$GITHUB_PATH" 2>/dev/null \
                || echo "$HOME/.reachable/venv/bin" >> "$GITHUB_PATH"
            grep -qxF "$HOME/.reachable/tools/bin" "$GITHUB_PATH" 2>/dev/null \
                || echo "$HOME/.reachable/tools/bin" >> "$GITHUB_PATH"
        fi
        configure_shell_path
        return
    fi
    
    # Remote install - download from GitHub
    print_step "Downloading wheel"
    
    mkdir -p "$REACHABLE_TMP_ROOT"
    DOWNLOAD_DIR=$(mktemp -d "$REACHABLE_TMP_ROOT/install.XXXXXX")
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

    # ── SHA-256 checksum verification (F-005: fail-closed) ─────────────────
    print_step "Verifying integrity"
    CHECKSUM_URL="https://github.com/${REPO}/releases/download/v${VERSION}/checksums.sha256"
    if ! curl -fsSL -L "$CHECKSUM_URL" -o checksums.sha256 2>/dev/null; then
        print_error "Could not fetch checksums.sha256 — aborting (supply chain risk)"
        print_info "URL: $CHECKSUM_URL"
        print_info "This file MUST exist for every release. If missing, the release may be compromised."
        exit 1
    fi
    if ! grep -q "$WHEEL_FILE" checksums.sha256; then
        print_error "No checksum entry for $WHEEL_FILE — aborting (supply chain risk)"
        print_info "The checksums.sha256 file exists but does not contain an entry for this wheel."
        print_info "This means the wheel was not built by CI or was tampered with after signing."
        exit 1
    fi
    EXPECTED=$(grep "$WHEEL_FILE" checksums.sha256 | awk '{print $1}')
    if command -v sha256sum &>/dev/null; then
        ACTUAL=$(sha256sum "$WHEEL_FILE" | awk '{print $1}')
    else
        ACTUAL=$(shasum -a 256 "$WHEEL_FILE" | awk '{print $1}')
    fi
    if [[ "$EXPECTED" != "$ACTUAL" ]]; then
        print_error "SHA-256 checksum FAILED — aborting"
        print_info "Expected: $EXPECTED"
        print_info "Actual:   $ACTUAL"
        exit 1
    fi
    print_ok "SHA-256 checksum verified"

    # ── Cosign: auto-install if missing ──────────────────────────────────────
    if ! command -v cosign &>/dev/null; then
        if [[ "$OS" == "darwin" ]] && command -v brew &>/dev/null; then
            if ! brew install cosign 2>/dev/null; then
                print_error "Failed to install cosign via Homebrew — aborting"
                print_info "Install manually: brew install cosign"
                exit 1
            fi
            print_ok "Installed cosign via Homebrew"
        elif [[ "$OS" == "linux" ]]; then
            COSIGN_ARCH=$(uname -m)
            if [[ "$COSIGN_ARCH" == "x86_64" ]]; then
                COSIGN_ARCH="amd64"
            elif [[ "$COSIGN_ARCH" == "aarch64" ]]; then
                COSIGN_ARCH="arm64"
            fi
            COSIGN_URL="https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-${COSIGN_ARCH}"
            local cosign_tmp
            cosign_tmp=$(mktemp "$REACHABLE_TMP_ROOT/cosign.XXXXXX")
            if ! curl -fsSL --max-time 30 "$COSIGN_URL" -o "$cosign_tmp" 2>/dev/null; then
                print_error "Failed to download cosign — aborting"
                print_info "URL: $COSIGN_URL"
                print_info "Install manually: https://docs.sigstore.dev/cosign/system_config/installation/"
                exit 1
            fi
            chmod +x "$cosign_tmp"
            mkdir -p "$HOME/.reachable/tools/bin"
            mv "$cosign_tmp" "$HOME/.reachable/tools/bin/cosign"
            # F-009c: idempotent PATH append (CWE-426)
            case ":$PATH:" in
                *":$HOME/.reachable/tools/bin:"*) ;;
                *) export PATH="$HOME/.reachable/tools/bin:$PATH" ;;
            esac
            print_ok "Installed cosign to ~/.reachable/tools/bin/"
        else
            print_error "cosign not available and cannot auto-install on this platform — aborting"
            print_info "Install manually: https://docs.sigstore.dev/cosign/system_config/installation/"
            exit 1
        fi
    fi

    # ── Cosign signature verification (F-005: fail-closed) ────────────────────
    COSIGN_BUNDLE="${WHEEL_FILE}.cosign.bundle"
    BUNDLE_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${COSIGN_BUNDLE}"
    if ! curl -fsSL -L "$BUNDLE_URL" -o "$COSIGN_BUNDLE" 2>/dev/null; then
        print_error "Could not fetch cosign bundle — aborting (supply chain risk)"
        print_info "URL: $BUNDLE_URL"
        print_info "Every release MUST include a cosign signature bundle."
        exit 1
    fi
    if ! cosign verify-blob \
        --bundle "$COSIGN_BUNDLE" \
        --certificate-identity-regexp "https://github.com/sthenos-security/" \
        --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
        "$WHEEL_FILE" &>/dev/null; then
        print_error "Cosign signature verification FAILED — aborting"
        print_info "The wheel was not signed by Sthenos Security CI or was tampered with."
        exit 1
    fi
    print_ok "Cosign signature verified (Sigstore)"

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
    HAS_VENDOR_REMOTE=false
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
                _retag_vendor_wheels vendor/
                HAS_VENDOR_REMOTE=true
                print_ok "Vendor wheels prepared (built and signed in CI)"
            fi
        else
            print_info "No vendor wheels for this platform — dependencies from PyPI"
        fi
    fi

    # ── Pre-install vendor wheels ──────────────────────────────────────────
    # Vendor wheels contain C extensions (yara-python, psutil, ruamel-yaml-clib)
    # built in CI.  Some are deps of guarddog, not reachable — so --find-links
    # alone won't install them (pip only resolves deps of the main package).
    # Install ALL vendor wheels explicitly first, then install the main wheel.
    if [[ "$HAS_VENDOR_REMOTE" == true ]]; then
        # F-009b: vendor wheel install failure is meaningful — do not swallow (CWE-755)
        if ! "$HOME/.reachable/venv/bin/pip" install --no-deps --force-reinstall vendor/*.whl -q 2>&1; then
            print_warn "Some vendor wheels failed to install — main install may still succeed"
        fi
    fi

    # Install the main wheel.  --find-links lets pip resolve any remaining
    # dependencies from the vendor directory; --only-binary for each vendor
    # package prevents fallback to source builds when no compiler is present.
    VENDOR_FIND_LINKS_REMOTE=""
    if [[ "$HAS_VENDOR_REMOTE" == true ]]; then
        VENDOR_FIND_LINKS_REMOTE="--find-links vendor/"
    fi
    set +e
    # shellcheck disable=SC2086,SC2046 -- intentional word-splitting for optional pip flags
    PIP_OUTPUT=$("$HOME/.reachable/venv/bin/pip" install \
        $VENDOR_FIND_LINKS_REMOTE \
        $(_vendor_only_binary_flags vendor/) \
        $CONSTRAINTS_FLAG "$WHEEL_FILE" 2>&1)
    PIP_RC=$?
    set -e
    if [[ $PIP_RC -ne 0 ]]; then
        print_error "pip install failed (exit $PIP_RC)"
        echo "$PIP_OUTPUT" | tail -30
        if [[ "$HAS_VENDOR_REMOTE" == true ]]; then
            echo ""
            print_error "Vendor wheels were pre-installed but pip still failed."
            print_error "Report to: info@sthenosec.com"
        fi
        exit 1
    fi
    print_ok "Installation complete"

    # Write venv-initialized stamp — tells doctor not to re-resolve vendor packages.
    # Contains the list of vendor-installed packages so guarddog backfill skips them.
    if [[ "$HAS_VENDOR_REMOTE" == true ]]; then
        STAMP="$HOME/.reachable/venv/.vendor-stamp"
        : > "$STAMP"
        for whl in vendor/*.whl; do
            [[ -f "$whl" ]] || continue
            pkg=$(basename "$whl" | sed 's/-[0-9].*//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
            echo "$pkg" >> "$STAMP"
        done
    fi

    # Restore the caller's working directory before deleting the temp tree.
    # This matters for curl | bash --vibe installs, where reach-vibe should
    # default to the repo the user launched the installer from, not the
    # transient download directory.
    if [[ -d "$INSTALLER_START_PWD" ]]; then
        cd "$INSTALLER_START_PWD"
    fi

    # Cleanup
    rm -rf "$DOWNLOAD_DIR"

    # If running in GitHub Actions, add venv + tools to PATH for subsequent steps
    if [[ -n "${GITHUB_PATH:-}" ]]; then
        # F-009c: idempotent — don't double-append on re-runs (CWE-426)
        grep -qxF "$HOME/.reachable/venv/bin" "$GITHUB_PATH" 2>/dev/null \
            || echo "$HOME/.reachable/venv/bin" >> "$GITHUB_PATH"
        grep -qxF "$HOME/.reachable/tools/bin" "$GITHUB_PATH" 2>/dev/null \
            || echo "$HOME/.reachable/tools/bin" >> "$GITHUB_PATH"
    fi

    configure_shell_path
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

resolve_vibe_workspace() {
    if [[ -n "$VIBE_WORKSPACE" ]]; then
        echo "$VIBE_WORKSPACE"
        return
    fi
    if [[ -n "${INSTALLER_START_PWD:-}" ]] && [[ -d "$INSTALLER_START_PWD" ]]; then
        if command -v git &>/dev/null; then
            if git -C "$INSTALLER_START_PWD" rev-parse --show-toplevel &>/dev/null; then
                git -C "$INSTALLER_START_PWD" rev-parse --show-toplevel
                return
            fi
        fi
        echo "$INSTALLER_START_PWD"
        return
    fi
    if command -v git &>/dev/null; then
        if git -C "$PWD" rev-parse --show-toplevel &>/dev/null; then
            git -C "$PWD" rev-parse --show-toplevel
            return
        fi
    fi
    echo "$PWD"
}

run_vibe_setup() {
    if [[ "$ENABLE_VIBE_CODING" != true ]]; then
        return
    fi

    local reachctl_bin="$HOME/.reachable/venv/bin/reachctl"
    local workspace
    workspace="$(resolve_vibe_workspace)"

    print_step "Configuring reach-vibe"
    print_info "Workspace: $workspace"

    if [[ ! -x "$reachctl_bin" ]]; then
        print_warn "reachctl binary not found after install; skipping reach-vibe setup"
        print_info "Retry with the installer from your repo root:"
        print_info "  curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --vibe --repo /path/to/repo"
        return
    fi

    if [[ ! -d "$workspace" ]]; then
        print_warn "Workspace not found: $workspace"
        print_info "Retry with the installer and an explicit repo path:"
        print_info "  curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --vibe --repo /path/to/repo"
        return
    fi

    if [[ ! -d "$workspace/.git" ]]; then
        if ! command -v git &>/dev/null || ! git -C "$workspace" rev-parse --show-toplevel &>/dev/null; then
            print_warn "Workspace does not look like a git repository; skipping reach-vibe setup"
            print_info "Retry from your repo root with the installer:"
            print_info "  curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --vibe"
            return
        fi
    fi

    local -a vibe_cmd=("$reachctl_bin" vibe install --repo "$workspace" --ci)
    local agent_name
    for agent_name in "${VIBE_AGENTS[@]}"; do
        vibe_cmd+=(--agent "$agent_name")
    done
    if [[ "$VIBE_SKIP_BASELINE" == true ]]; then
        vibe_cmd+=(--no-auto-vibe)
    fi

    if "${vibe_cmd[@]}"; then
        print_ok "reach-vibe installed for $workspace"
    else
        print_warn "reach-vibe setup failed, but REACHABLE itself is installed"
        print_info "Retry later with: ${vibe_cmd[*]}"
    fi
}

# -----------------------------------------------------------------------------
# Print Success Message
# -----------------------------------------------------------------------------
print_success() {
    local check_updates_cmd="curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --list"
    local upgrade_cmd="curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --update"
    local path_hint=""
    if [[ "$ENABLE_VIBE_CODING" == true ]]; then
        upgrade_cmd="curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --update --vibe"
    fi
    case "$PATH_CONFIG_STATUS" in
        updated)
            path_hint="PATH configured in $PATH_CONFIG_TARGET — open a new shell to pick it up."
            ;;
        already-configured)
            path_hint="PATH already configured in $PATH_CONFIG_TARGET."
            ;;
        *)
            path_hint="~/.reachable/venv/bin is available to the installer runtime."
            ;;
    esac

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
    echo -e "  ${BOLD}Next:${NC}"
    echo "    reachctl scan /path      # Scan a repository"
    if [[ "$ENABLE_VIBE_CODING" == true ]]; then
        echo "    reachctl vibe status     # Show bundled reach-vibe daemon status"
    fi
    echo "    reachctl primer          # Full quick-start guide"
    echo "    $path_hint"
    echo ""
    echo -e "  ${BOLD}Enable AI:${NC}"
    echo "    Strongly recommended for better verdict quality and performance."
    echo "    Standard SDLC:  reachctl doctor set openrouter-api-key   # https://openrouter.ai/keys"
    echo "    Codex / OpenAI: reachctl doctor set openai-api-key      # https://platform.openai.com/api-keys"
    echo "    Claude Code:    reachctl doctor set anthropic-api-key   # https://console.anthropic.com/settings/keys"
    echo ""
    if [[ -n "$BACKUP_DIR" ]]; then
        echo -e "  ${BOLD}Backup:${NC} $BACKUP_DIR"
        echo ""
    fi
    echo -e "  ${BOLD}Maintain:${NC}"
    echo "    Installed: v${VERSION}"
    echo "    Releases:  $check_updates_cmd"
    echo "    Upgrade:   $upgrade_cmd"
    echo ""
    echo "  Docs: https://sthenosec.com  |  Support: info@sthenosec.com"
    echo "  © 2026 Sthenos Security. All rights reserved."
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
    run_vibe_setup
    print_success
}

main "$@"
