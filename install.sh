#!/usr/bin/env bash
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
#  Installs REACHABLE into ~/.reachable/venv (never modifies the host OS).
#
#  Usage:
#
#    # Option 1: Clone and run (prompts for GitHub auth)
#    git clone https://github.com/sthenos-security/reach-dist.git
#    cd reach-dist && ./install.sh
#
#    # Option 2: curl with token
#    export GITHUB_TOKEN=ghp_xxxx
#    curl -H "Authorization: token $GITHUB_TOKEN" \
#      -H "Accept: application/vnd.github.v3.raw" \
#      -sL https://api.github.com/repos/sthenos-security/reach-dist/contents/install.sh | bash
#
#    # Option 3: Local wheel install (download both files first)
#    ./install.sh --wheel ./wheels/latest/reachable-1.0.0b14-cp311-*.whl
#
#  Other options:
#    ./install.sh --update    # Upgrade with backup
#    ./install.sh --clean     # Clean install (removes data)
#    ./install.sh --version 1.0.0-beta13
#
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
VERSION="1.0.0b14"
WHEEL_VERSION="1.0.0b14"
REPO="sthenos-security/reach-dist"
VENV_DIR="$HOME/.reachable/venv"
VENV_BIN="$VENV_DIR/bin"

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
            echo "  --version, -v VER  Install specific version (e.g., 1.0.0-beta13)"
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

# Apply custom version if specified
if [[ -n "$CUSTOM_VERSION" ]]; then
    # Normalize to Python wheel format (1.0.0b11 not 1.0.0-beta11)
    VERSION=$(echo "$CUSTOM_VERSION" | sed 's/-beta/b/')
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

    # Find Python — try candidates in order of preference
    PYTHON=""
    for candidate in python3.14 python3.13 python3.12 python3.11 python3.10 python3 python; do
        if command -v "$candidate" &> /dev/null; then
            # Verify it's actually Python 3.10+
            PY_VER=$( "$candidate" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "" )
            if [[ -n "$PY_VER" ]]; then
                PY_MAJ=$(echo "$PY_VER" | cut -d. -f1)
                PY_MIN=$(echo "$PY_VER" | cut -d. -f2)
                if [[ "$PY_MAJ" -gt 3 ]] || { [[ "$PY_MAJ" -eq 3 ]] && [[ "$PY_MIN" -ge 10 ]]; }; then
                    PYTHON="$candidate"
                    break
                fi
            fi
        fi
    done

    if [[ -z "$PYTHON" ]]; then
        print_error "Python 3.10+ not found"
        print_info "Tried: python3.14, python3.13, ..., python3.10, python3, python"
        echo ""
        echo "  Install Python 3.10+ for your platform:"
        if [[ "$OS" == "darwin" ]]; then
            echo "    brew install python@3.13"
            echo "    or download from https://python.org/downloads/macos/"
        else
            echo "    Ubuntu/Debian:  sudo apt install python3 python3-venv"
            echo "    Fedora/RHEL:    sudo dnf install python3"
            echo "    Amazon Linux:   sudo yum install python3"
            echo "    Alpine:         apk add python3"
            echo "    Or download:    https://python.org/downloads/"
        fi
        exit 1
    fi

    PY_VERSION=$( "$PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" )
    PY_MAJOR=$(echo $PY_VERSION | cut -d. -f1)
    PY_MINOR=$(echo $PY_VERSION | cut -d. -f2)

    if [[ "$PY_MAJOR" -lt 3 ]] || [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 10 ]]; then
        print_error "Python 3.10+ required (found $PY_VERSION)"
        exit 1
    fi

    PY_TAG="cp${PY_VERSION//./}"

    # Platform tag for wheel
    if [[ "$OS" == "darwin" ]]; then
        if [[ "$PY_MINOR" -ge 14 ]]; then
            PLATFORM_TAG="macosx_10_15_universal2"
        elif [[ "$PY_MINOR" -ge 12 ]]; then
            PLATFORM_TAG="macosx_10_13_universal2"
        else
            PLATFORM_TAG="macosx_10_9_universal2"
        fi
    else
        if [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
            PLATFORM_TAG="linux_aarch64"
        else
            PLATFORM_TAG="linux_x86_64"
        fi
    fi

    WHEEL_FILE="reachable-${WHEEL_VERSION}-${PY_TAG}-${PY_TAG}-${PLATFORM_TAG}.whl"

    print_ok "OS:           $OS_NAME $ARCH_NAME"
    print_ok "Python:       $PY_VERSION ($PY_TAG) [$PYTHON]"
    print_ok "Wheel:        $WHEEL_FILE"
}

# -----------------------------------------------------------------------------
# Setup GitHub CLI
# -----------------------------------------------------------------------------
setup_gh_cli() {
    print_step "Checking GitHub CLI"

    if command -v gh &> /dev/null; then
        GH_VERSION=$(gh --version | head -1 | awk '{print $3}')
        print_ok "GitHub CLI installed (v$GH_VERSION)"
    else
        print_warn "GitHub CLI not found — installing..."

        if [[ "$OS" == "darwin" ]]; then
            if command -v brew &> /dev/null; then
                brew install gh
            else
                print_error "Homebrew not found. Install from https://brew.sh"
                exit 1
            fi
        elif [[ "$OS" == "linux" ]]; then
            if command -v apt-get &> /dev/null; then
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                sudo apt-get update -qq
                sudo apt-get install -y gh
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y gh
            elif command -v yum &> /dev/null; then
                sudo yum install -y gh
            else
                print_error "Could not detect package manager"
                echo ""
                echo "  Install GitHub CLI manually:"
                echo "  https://github.com/cli/cli#installation"
                exit 1
            fi
        fi

        print_ok "GitHub CLI installed"
    fi

    # Check authentication
    print_step "Checking GitHub authentication"

    if gh auth status &> /dev/null; then
        GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "authenticated")
        print_ok "Logged in as: $GH_USER"
    else
        print_warn "Not authenticated — starting login..."
        echo ""
        echo -e "  ${DIM}A browser window will open, or you'll see a code to enter at github.com/login/device${NC}"
        echo ""
        gh auth login -h github.com -p https -w
        print_ok "Authentication complete"
    fi
}

# -----------------------------------------------------------------------------
# Handle Existing Installation
# -----------------------------------------------------------------------------
handle_existing_install() {
    INSTALLED_VERSION=""
    BACKUP_DIR=""

    # Check for existing install in venv
    if [[ -f "$VENV_BIN/reachctl" ]]; then
        INSTALLED_VERSION=$( "$VENV_BIN/pip" show reachable 2>/dev/null | grep "^Version:" | awk '{print $2}' || echo "" )
    fi

    if [[ -n "$INSTALLED_VERSION" ]]; then
        print_step "Existing installation detected"
        print_info "Installed version: $INSTALLED_VERSION"
        print_info "Target version:    $WHEEL_VERSION"

        if [[ "$UPDATE_MODE" == true ]]; then
            # Backup existing data (not the venv itself, just scan data)
            if [[ -d "$HOME/.reachable" ]]; then
                BACKUP_DIR="$HOME/.reachable.backup.$(date +%Y%m%d-%H%M%S)"
                print_step "Backing up existing data"
                # Copy everything except venv
                mkdir -p "$BACKUP_DIR"
                find "$HOME/.reachable" -maxdepth 1 -not -name venv -not -name .reachable -exec cp -r {} "$BACKUP_DIR/" \; 2>/dev/null || true
                print_ok "Backup created: $BACKUP_DIR"
            fi
        elif [[ "$CLEAN_DATA" == false ]]; then
            echo ""
            print_warn "REACHABLE is already installed (v$INSTALLED_VERSION)"
            echo ""
            echo -e "  ${BOLD}Options:${NC}"
            echo "    • To upgrade (keeps data):    ./install.sh --update"
            echo "    • To clean install (beta):    ./install.sh --clean"
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
# Virtual Environment Setup
# -----------------------------------------------------------------------------
setup_venv() {
    print_step "Setting up virtual environment"

    mkdir -p "$HOME/.reachable"

    if [[ -d "$VENV_DIR" ]] && [[ -f "$VENV_BIN/python" ]]; then
        # Check if existing venv Python version matches system Python
        VENV_PY=$( "$VENV_BIN/python" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "" )
        if [[ "$VENV_PY" == "$PY_VERSION" ]]; then
            print_ok "Virtual environment exists (Python $VENV_PY)"
            return
        else
            print_warn "Python version changed ($VENV_PY → $PY_VERSION) — recreating venv"
            rm -rf "$VENV_DIR"
        fi
    fi

    if ! "$PYTHON" -m venv "$VENV_DIR" 2>/dev/null; then
        # Common failure: python3-venv not installed on Debian/Ubuntu
        if [[ "$OS" == "linux" ]] && command -v apt-get &> /dev/null; then
            print_error "Failed to create virtual environment"
            echo ""
            echo "  The venv module is missing. Install it with:"
            echo "    sudo apt install python3-venv"
            echo "    # or for a specific version:"
            echo "    sudo apt install python${PY_VERSION}-venv"
        else
            print_error "Failed to create virtual environment"
            print_info "Ensure the Python venv module is available"
        fi
        exit 1
    fi
    "$VENV_BIN/python" -m pip install --upgrade pip -q
    print_ok "Created virtual environment at $VENV_DIR (via $PYTHON)"
}

# -----------------------------------------------------------------------------
# Download & Install
# -----------------------------------------------------------------------------
download_and_install() {
    # Set up venv first
    setup_venv

    VENV_PIP="$VENV_BIN/pip"

    # If local wheel provided, use it directly
    if [[ -n "$LOCAL_WHEEL" ]]; then
        print_step "Installing from local wheel"

        if [[ ! -f "$LOCAL_WHEEL" ]]; then
            print_error "Wheel file not found: $LOCAL_WHEEL"
            exit 1
        fi

        print_info "File: $LOCAL_WHEEL"

        print_step "Installing REACHABLE"
        "$VENV_PIP" install --force-reinstall "$LOCAL_WHEEL" -q
        print_ok "Installation complete"
        return
    fi

    # Remote install — download from GitHub
    print_step "Downloading wheel"

    DOWNLOAD_DIR=$(mktemp -d)
    cd "$DOWNLOAD_DIR"

    print_info "Repository: github.com/$REPO"
    print_info "Release:    v$VERSION"
    print_info "File:       $WHEEL_FILE"

    if ! gh release download "v${VERSION}" --repo "$REPO" --pattern "$WHEEL_FILE" 2>/dev/null; then
        print_error "Download failed"
        echo ""
        echo "  Possible causes:"
        echo "    • No access to repository (contact adazzi@sthenosec.com)"
        echo "    • Wheel for Python $PY_VERSION not available"
        echo "    • Version v$VERSION does not exist"
        echo ""
        echo "  Available releases:"
        gh release list --repo "$REPO" --limit 5 2>/dev/null | sed 's/^/    /' || echo "    (unable to list)"
        echo ""
        echo "  Available wheels in v$VERSION:"
        gh release view "v${VERSION}" --repo "$REPO" --json assets --jq '.assets[].name' 2>/dev/null | sed 's/^/    /' || echo "    (unable to list)"
        exit 1
    fi

    print_ok "Downloaded successfully"

    print_step "Installing REACHABLE v$VERSION"
    "$VENV_PIP" install --force-reinstall "$WHEEL_FILE" -q
    print_ok "Installation complete"

    # Cleanup
    cd "$HOME"
    rm -rf "$DOWNLOAD_DIR"
}

# -----------------------------------------------------------------------------
# Configure PATH
# -----------------------------------------------------------------------------
configure_path() {
    print_step "Configuring PATH"

    # Check if already on PATH
    if echo "$PATH" | tr ':' '\n' | grep -q "^${VENV_BIN}$"; then
        print_ok "Already on PATH"
        return
    fi

    SHELL_NAME=$(basename "$SHELL")
    SHELL_RC=""
    PATH_LINE="export PATH=\"\$HOME/.reachable/venv/bin:\$PATH\""

    case "$SHELL_NAME" in
        zsh)  SHELL_RC="$HOME/.zshrc" ;;
        bash)
            if [[ "$OS" == "darwin" ]]; then
                SHELL_RC="$HOME/.bash_profile"
            else
                SHELL_RC="$HOME/.bashrc"
            fi
            ;;
        fish)
            SHELL_RC="$HOME/.config/fish/config.fish"
            PATH_LINE="set -gx PATH \$HOME/.reachable/venv/bin \$PATH"
            ;;
        *)
            print_warn "Unknown shell ($SHELL_NAME) — add manually:"
            echo "    $PATH_LINE"
            return
            ;;
    esac

    # Check if already in rc file
    if [[ -f "$SHELL_RC" ]] && grep -q '.reachable/venv/bin' "$SHELL_RC"; then
        print_ok "PATH already configured in $SHELL_RC"
    else
        echo "" >> "$SHELL_RC"
        echo "# REACHABLE" >> "$SHELL_RC"
        echo "$PATH_LINE" >> "$SHELL_RC"
        print_ok "Added to $SHELL_RC"
    fi

    # Export for current session
    export PATH="$VENV_BIN:$PATH"
}

# -----------------------------------------------------------------------------
# Verify Installation
# -----------------------------------------------------------------------------
verify_installation() {
    print_header "Verification"

    # 1. Self-test: verify the wheel is functional
    echo ""
    echo -e "${BOLD}Self-test:${NC}"
    if "$VENV_BIN/reachctl" selftest 2>&1 | sed 's/^/  /'; then
        print_ok "All checks passed"
    else
        print_warn "Some tests failed (non-fatal)"
    fi

    # 2. Doctor: install missing external tools (syft, grype, guarddog, etc.)
    echo ""
    echo -e "${BOLD}Installing dependencies:${NC}"
    "$VENV_BIN/reachctl" doctor 2>&1 | sed 's/^/  /'
    print_ok "Dependency check complete"

    # 3. Version: show final state with all tools installed
    echo ""
    echo -e "${BOLD}Version:${NC}"
    "$VENV_BIN/reachctl" version 2>&1 | sed 's/^/  /'
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
    echo -e "  ${BOLD}Installation:${NC}  ~/.reachable/venv"
    echo -e "  ${BOLD}Executable:${NC}    ~/.reachable/venv/bin/reachctl"
    echo ""

    # Check if user needs to reload shell
    if ! command -v reachctl &> /dev/null; then
        echo -e "  ${YELLOW}⚠${NC} Restart your terminal or run:"
        echo "    source ~/.zshrc    # (or ~/.bashrc)"
        echo ""
    fi

    echo -e "  ${BOLD}Quick Start:${NC}"
    echo ""
    echo "    reachctl primer          # View quick-start guide"
    echo "    reachctl scan /path      # Scan a repository"
    echo ""
    if [[ -n "$BACKUP_DIR" ]]; then
        echo -e "  ${BOLD}Note:${NC} Previous data backed up to:"
        echo "    $BACKUP_DIR"
        echo ""
    fi
    echo -e "  ${BOLD}Future Upgrades:${NC}"
    echo "    cd /path/to/reach-dist && git pull && ./install.sh --update"
    echo ""
    echo -e "  ${BOLD}Support:${NC}"
    echo "    📧 Email: adazzi@sthenosec.com"
    echo "    💬 Slack: https://sthenossecuri-yxh9464.slack.com/archives/C0AACF3JSEM"
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

    # Only need GitHub CLI for remote installs
    if [[ -z "$LOCAL_WHEEL" ]]; then
        setup_gh_cli
    fi

    handle_existing_install
    download_and_install
    configure_path
    verify_installation
    print_success
}

main "$@"
