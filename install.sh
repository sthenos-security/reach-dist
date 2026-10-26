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
#  Copyright © 2026 Sthenos Security, Inc. All rights reserved.
#
#  Usage:
#
#    # Standard install (no auth required).  Installs the scanner AND the
#    # continuous surface: daemon, agent hooks, MCP server, generated skills.
#    curl -fsSL https://sthenosec.com/download/install.sh | bash
#
#    # Scanner only — CI runners and other ephemeral, non-interactive hosts
#    curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --no-vibe
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
REACHABLE_INSTALL_LOG_DIR="${REACHABLE_INSTALL_LOG_DIR:-$HOME/.reachable/logs/install}"
PUBLIC_INSTALL_URL="${PUBLIC_INSTALL_URL:-https://sthenosec.com/download/install.sh}"
LATEST_MANIFEST_URL="${LATEST_MANIFEST_URL:-https://sthenosec.com/download/latest.json}"
REACHABLE_DOWNLOAD_RETRIES="${REACHABLE_DOWNLOAD_RETRIES:-3}"
REACHABLE_DOWNLOAD_RETRY_DELAY="${REACHABLE_DOWNLOAD_RETRY_DELAY:-5}"
REACHABLE_DOWNLOAD_CONNECT_TIMEOUT="${REACHABLE_DOWNLOAD_CONNECT_TIMEOUT:-20}"
REACHABLE_DOWNLOAD_MAX_TIME="${REACHABLE_DOWNLOAD_MAX_TIME:-600}"
REACHABLE_PIP_ATTEMPTS="${REACHABLE_PIP_ATTEMPTS:-3}"
REACHABLE_PIP_RETRIES="${REACHABLE_PIP_RETRIES:-5}"
REACHABLE_PIP_TIMEOUT="${REACHABLE_PIP_TIMEOUT:-120}"
REACHABLE_PIP_PROGRESS_BAR="${REACHABLE_PIP_PROGRESS_BAR:-off}"
REACHABLE_PIP_VERBOSE="${REACHABLE_PIP_VERBOSE:-0}"
REACHABLE_INSTALLER_AGENT_SETUP="${REACHABLE_INSTALLER_AGENT_SETUP:-0}"
if [[ "$REACHABLE_INSTALLER_AGENT_SETUP" == "1" ]]; then
    REACHABLE_INSTALL_PROGRESS_INTERVAL="${REACHABLE_INSTALL_PROGRESS_INTERVAL:-60}"
else
    REACHABLE_INSTALL_PROGRESS_INTERVAL="${REACHABLE_INSTALL_PROGRESS_INTERVAL:-30}"
fi
REACHABLE_DIST_ROOT="${REACHABLE_DIST_ROOT:-}"
REACHABLE_DIST_BASE_URL="${REACHABLE_DIST_BASE_URL:-}"
INSTALL_LOG=""
SKIP_RUNTIME_INSTALL=false

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
REPO="sthenos-security/reach-dist"
RELEASES_API_TOKEN="${GITHUB_TOKEN:-${MCP_GITHUB_TOKEN:-}}"

github_curl() {
    if [[ -n "${RELEASES_API_TOKEN:-}" ]]; then
        printf 'header = "Authorization: Bearer %s"\n' "${RELEASES_API_TOKEN}" \
            | curl --config - "$@"
    else
        curl "$@"
    fi
}

download_with_retries() {
    local label="$1"
    local url="$2"
    local output="$3"
    shift 3
    local partial="${output}.part.$$"

    local curl_retry_all_errors=()
    if curl --help all 2>/dev/null | grep -q -- '--retry-all-errors'; then
        curl_retry_all_errors=(--retry-all-errors)
    fi

    print_info "$label"
    print_info "Timeout: ${REACHABLE_DOWNLOAD_MAX_TIME}s; retries: ${REACHABLE_DOWNLOAD_RETRIES}"
    rm -f "$partial"

    if [[ -n "${RELEASES_API_TOKEN:-}" ]]; then
        printf 'header = "Authorization: Bearer %s"\n' "${RELEASES_API_TOKEN}" \
            | curl --config - \
                --fail \
                --location \
                --silent \
                --show-error \
                --write-out "  downloaded %{size_download} bytes in %{time_total}s\n" \
                --connect-timeout "$REACHABLE_DOWNLOAD_CONNECT_TIMEOUT" \
                --max-time "$REACHABLE_DOWNLOAD_MAX_TIME" \
                --retry "$REACHABLE_DOWNLOAD_RETRIES" \
                --retry-delay "$REACHABLE_DOWNLOAD_RETRY_DELAY" \
                --retry-connrefused \
                "${curl_retry_all_errors[@]}" \
                "$@" \
                -o "$partial" \
                "$url" \
            && mv "$partial" "$output" \
            || { rm -f "$partial"; return 1; }
    else
        curl \
            --fail \
            --location \
            --silent \
            --show-error \
            --write-out "  downloaded %{size_download} bytes in %{time_total}s\n" \
            --connect-timeout "$REACHABLE_DOWNLOAD_CONNECT_TIMEOUT" \
            --max-time "$REACHABLE_DOWNLOAD_MAX_TIME" \
            --retry "$REACHABLE_DOWNLOAD_RETRIES" \
            --retry-delay "$REACHABLE_DOWNLOAD_RETRY_DELAY" \
            --retry-connrefused \
            "${curl_retry_all_errors[@]}" \
            "$@" \
            -o "$partial" \
            "$url" \
            && mv "$partial" "$output" \
            || { rm -f "$partial"; return 1; }
    fi
}

resolve_python_bin() {
    local candidate
    local candidates=()
    if [[ -n "${PYTHON:-}" ]]; then
        candidates+=("$PYTHON")
    fi
    candidates+=(python3.14 python3.13 python3.12 python3.11 python3)

    for candidate in "${candidates[@]}"; do
        if ! command -v "$candidate" >/dev/null 2>&1; then
            continue
        fi
        local path
        path="$(command -v "$candidate")"
        if [[ ! -x "$path" ]]; then
            continue
        fi
        # Never run the installer on the managed venv's own python. The plugin's
        # setup.sh exports PYTHON=$HOME/.reachable/venv/bin/python, and an
        # install that rebuilds the venv `rm -rf`s it -- deleting the
        # interpreter mid-run, so the next `"$PY_BIN" -m venv` fails and leaves
        # no venv at all (reported on Linux 2026-10-26). Use the interpreter the
        # venv was created from; a venv python that cannot start is skipped like
        # any other unusable candidate.
        case "$path" in
            "$HOME/.reachable/venv/"*)
                if ! path="$("$path" -c 'import sys; print(sys._base_executable)' 2>/dev/null)"; then
                    continue
                fi
                ;;
        esac
        local version
        version="$("$path" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)"
        if [[ -z "$version" ]]; then
            continue
        fi
        local major minor
        major="$(echo "$version" | cut -d. -f1)"
        minor="$(echo "$version" | cut -d. -f2)"
        if [[ "$major" -gt 3 || ( "$major" -eq 3 && "$minor" -ge 11 ) ]]; then
            # Containers like python:3.11 may expose multiple python3.x
            # binaries, but only the one matching the image has ensurepip.
            # Actually create a test venv; --help passes even without ensurepip.
            local test_venv
            test_venv="$(mktemp -d "${TMPDIR:-/tmp}/reachable-python-probe.XXXXXX")"
            if ! "$path" -m venv "$test_venv" >/dev/null 2>&1; then
                rm -rf "$test_venv"
                continue
            fi
            rm -rf "$test_venv"
            printf '%s\n' "$path"
            return 0
        fi
    done
    return 1
}

resolve_version_from_manifest() {
    local response
    response=$(curl -fsSL "$LATEST_MANIFEST_URL" 2>/dev/null || true)
    if [[ -z "$response" ]]; then
        return 1
    fi

    echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not isinstance(data, dict) or not data.get('ok'):
    sys.exit(1)
version = str(data.get('version', '')).strip()
if not version:
    sys.exit(1)
print(version)
"
}

_manifest_version_from_json() {
    python3 -c "
import sys, json
data = json.load(sys.stdin)
if not isinstance(data, dict) or not data.get('ok'):
    sys.exit(1)
version = str(data.get('version', '')).strip()
if not version:
    sys.exit(1)
print(version)
"
}

candidate_dist_source_enabled() {
    [[ -n "${REACHABLE_DIST_ROOT:-}" || -n "${REACHABLE_DIST_BASE_URL:-}" ]]
}

resolve_version_from_candidate_dist() {
    if bundle_mode_enabled; then
        resolve_version_from_bundle
        return $?
    fi
    if [[ -n "${REACHABLE_DIST_ROOT:-}" ]]; then
        local manifest="${REACHABLE_DIST_ROOT%/}/latest.json"
        if [[ -f "$manifest" ]]; then
            _manifest_version_from_json < "$manifest"
            return 0
        fi
        return 1
    fi

    if [[ -n "${REACHABLE_DIST_BASE_URL:-}" ]]; then
        local response
        response=$(curl -fsSL "${REACHABLE_DIST_BASE_URL%/}/latest.json" 2>/dev/null || true)
        if [[ -z "$response" ]]; then
            return 1
        fi
        echo "$response" | _manifest_version_from_json
        return 0
    fi

    return 1
}

# Resolve latest version from the first-party download manifest, then fall back
# to the reach-dist GitHub releases API only if that manifest is unavailable.
# Uses GITHUB_TOKEN or MCP_GITHUB_TOKEN on the GitHub fallback path.
resolve_version() {
    local manifest_version
    manifest_version=$(resolve_version_from_manifest || true)
    if [[ -n "$manifest_version" ]]; then
        printf '%s\n' "$manifest_version"
        return 0
    fi

    local api_url="https://api.github.com/repos/${REPO}/releases"
    local response

    if [[ -n "${RELEASES_API_TOKEN:-}" ]]; then
        # F-006a: pass token via --config stdin, not CLI args (CWE-214)
        response=$(github_curl -sL "$api_url")
    else
        response=$(curl -sL "$api_url")
    fi

    echo "$response" | python3 -c "
import sys, json, os
data = json.load(sys.stdin)
if isinstance(data, dict):
    msg = data.get('message', 'unknown error')
    has_token = bool(os.environ.get('GITHUB_TOKEN','') or os.environ.get('MCP_GITHUB_TOKEN',''))
    if 'rate limit' in msg.lower():
        if has_token:
            sys.stderr.write('Error: GitHub API rate limit exceeded even with GITHUB_TOKEN or MCP_GITHUB_TOKEN.\n')
            sys.stderr.write('  Your token may be invalid or scoped incorrectly.\n')
        else:
            sys.stderr.write('Error: GitHub API rate limit exceeded (unauthenticated).\n')
            sys.stderr.write('  Fix option 1 — set a token and retry:\n')
            sys.stderr.write('    export GITHUB_TOKEN=\"your_token\"\n')
            sys.stderr.write('    # or: export MCP_GITHUB_TOKEN=\"your_token\"\n')
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
" GITHUB_TOKEN="${GITHUB_TOKEN:-}" MCP_GITHUB_TOKEN="${MCP_GITHUB_TOKEN:-}"
}

list_releases() {
    local api_url="https://api.github.com/repos/${REPO}/releases"
    local response

    if [[ -n "${RELEASES_API_TOKEN:-}" ]]; then
        # F-006a: pass token via --config stdin, not CLI args (CWE-214)
        response=$(github_curl -sL "$api_url")
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

release_tag_for_version() {
    local version="${1#v}"
    printf 'v%s\n' "$version"
}

# -----------------------------------------------------------------------------
# Air-gap bundle mode (AIRGAP-INSTALLER D36): the bundle is a release in scope
# reachable-airgap-bundle, so it installs through THIS installer and THIS
# verification -- the bundle directory is the dist root, nothing is fetched,
# and pip never reaches an index.
# -----------------------------------------------------------------------------
REACHABLE_AIRGAP_BUNDLE_ROOT="${REACHABLE_AIRGAP_BUNDLE_ROOT:-}"
BUNDLE_MANIFEST_NAME="reachable-signed-manifest.json"
BUNDLE_SCOPE="reachable-airgap-bundle"

bundle_mode_enabled() {
    [[ -n "${REACHABLE_AIRGAP_BUNDLE_ROOT:-}" ]]
}

# Extract a bundle tarball refusing anything but regular files and
# directories, absolute names and parent traversal (AIRGAP-INSTALLER C22),
# BEFORE a single member lands on disk.
# The signature verifier's own closure (cryptography, cffi, pycparser), cut
# from the signed constraints as a hash-pinned REQUIREMENTS file. Works with
# every pip a supported CPython (3.11-3.14) ships: pip before 26 ignores the
# hashes in a constraints file, so `-c constraints.txt cryptography` fails in
# --require-hashes mode. Tested by test-installer-verifier-oldest-pip.sh.
write_verifier_requirements() {
    awk 'BEGIN { keep = 0 }
         /^[A-Za-z0-9_.-]+==/ {
             name = tolower($1); sub(/==.*/, "", name)
             keep = (name == "cryptography" || name == "cffi" || name == "pycparser")
         }
         keep' "$1"
}

extract_bundle_archive() {
    local archive="$1" dest="$2"
    python3 -I - "$archive" "$dest" <<'BUNDLE_PY'
import sys, tarfile
archive, dest = sys.argv[1], sys.argv[2]
with tarfile.open(archive, "r:*") as tar:
    members = tar.getmembers()
    bad = [m.name for m in members
           if not (m.isfile() or m.isdir()) or m.name.startswith("/") or ".." in m.name.split("/")]
    if bad:
        sys.exit(f"bundle archive refused: unsafe member(s) {bad[:3]}")
    tar.extractall(dest, members=members, filter="data")
BUNDLE_PY
}

# The bundle root is the directory holding the bundle manifest: the given
# directory, or its single child (a tarball packed with a top-level folder).
locate_bundle_root() {
    local dir="$1"
    if [[ -f "$dir/$BUNDLE_MANIFEST_NAME" ]]; then
        printf '%s\n' "$dir"
        return 0
    fi
    local children=("$dir"/*/)
    if [[ ${#children[@]} -eq 1 && -f "${children[0]%/}/$BUNDLE_MANIFEST_NAME" ]]; then
        printf '%s\n' "${children[0]%/}"
        return 0
    fi
    return 1
}

# Names only: the version picks file names before verification; the signed
# manifest then binds every byte of those files.
resolve_version_from_bundle() {
    python3 -I -c 'import json,sys; v=json.load(open(sys.argv[1])).get("version"); print(v) if v else sys.exit(1)' \
        "${REACHABLE_AIRGAP_BUNDLE_ROOT%/}/$BUNDLE_MANIFEST_NAME"
}

dist_artifact_source() {
    local name="$1"
    if bundle_mode_enabled && [[ "$name" == *.whl ]]; then
        printf '%s/wheelhouse/%s\n' "${REACHABLE_AIRGAP_BUNDLE_ROOT%/}" "$name"
    elif [[ -n "${REACHABLE_DIST_ROOT:-}" ]]; then
        printf '%s/%s\n' "${REACHABLE_DIST_ROOT%/}" "$name"
    elif [[ -n "${REACHABLE_DIST_BASE_URL:-}" ]]; then
        printf '%s/%s\n' "${REACHABLE_DIST_BASE_URL%/}" "$name"
    else
        # RELEASE_TAG is set during normal argument resolution, but this function is
        # also reachable before that runs. Derive it from VERSION rather than dying
        # on an unbound variable -- and refuse outright if neither is known, since a
        # download URL with an empty tag in it is a 404 dressed up as progress.
        local tag="${RELEASE_TAG:-}"
        if [[ -z "$tag" && -n "${VERSION:-}" ]]; then
            tag="$(release_tag_for_version "$VERSION")"
        fi
        if [[ -z "$tag" ]]; then
            echo "Error: cannot build a download URL for '$name': neither RELEASE_TAG nor VERSION is set." >&2
            return 1
        fi
        printf 'https://github.com/%s/releases/download/%s/%s\n' "$REPO" "$tag" "$name"
    fi
}

download_dist_artifact() {
    local label="$1"
    local name="$2"
    local output="$3"
    local source
    source="$(dist_artifact_source "$name")"

    if [[ -n "${REACHABLE_DIST_ROOT:-}" ]]; then
        local partial="${output}.part.$$"
        print_info "$label"
        print_info "Source: $source"
        rm -f "$partial"
        if [[ ! -f "$source" ]]; then
            return 1
        fi
        cp "$source" "$partial" && mv "$partial" "$output" \
            || { rm -f "$partial"; return 1; }
        return 0
    fi

    download_with_retries "$label" "$source" "$output"
}

VERSION=""
WHEEL_VERSION=""
RELEASE_TAG=""

# -----------------------------------------------------------------------------
# Parse Arguments
# -----------------------------------------------------------------------------
UPDATE_MODE=false
CUSTOM_VERSION=""
CLEAN_DATA=false
LOCAL_WHEEL=""
AIRGAP_BUNDLE_INPUT=""
AIRGAP_MIRROR_ROOT=""

# REACHABLE has one install mode.  The continuous surface — daemon, agent
# hooks, MCP registration, and generated skills/rules — is installed by
# default, because the skills loop is the product.  CI runners and other
# ephemeral, non-interactive hosts opt out explicitly with --no-vibe.
#
# ENABLE_VIBE_CODING is resolved once, after argument parsing, so the outcome
# never depends on flag order.  The resolved surface and the reason for it are
# always printed; there is no silent branch.
#
# No CI auto-detection happens here.  That decision has exactly one authority:
# the sthenosec.com/download/install.sh bootstrap, which detects
# GITHUB_ACTIONS / GITLAB_CI / CI, prints what it found, and forwards an
# explicit --no-vibe or --vibe to this script.  A second detector here would
# let a direct-download user and a bootstrap user get different answers on the
# same machine with no way to tell which one decided.
ENABLE_VIBE_CODING=true
# Flag that asked for the full surface ("" if none was passed).
VIBE_REQUESTED_FLAG=""
# Flag that asked for the scanner only ("" if none was passed).
NO_VIBE_REQUESTED_FLAG=""
# Human-readable reason for the resolved surface, printed in the summary.
VIBE_SURFACE_REASON="default"
VIBE_WORKSPACE=""
UNINSTALL_MODE=false
ASSUME_YES=false
VIBE_RUN_BASELINE=false
VIBE_AGENTS=()
VIBE_UI_URL=""

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
        --dist-root)
            REACHABLE_DIST_ROOT="$2"
            shift 2
            ;;
        --dist-base-url)
            REACHABLE_DIST_BASE_URL="$2"
            shift 2
            ;;
        --clean)
            CLEAN_DATA=true
            shift
            ;;
        --uninstall)
            UNINSTALL_MODE=true
            shift
            ;;
        --yes|-y)
            ASSUME_YES=true
            shift
            ;;
        --wheel|-w)
            LOCAL_WHEEL="$2"
            shift 2
            ;;
        --bundle)
            # An air-gap bundle (tarball or unpacked directory). Installs offline
            # through the same verification as a release (AIRGAP-INSTALLER D36).
            AIRGAP_BUNDLE_INPUT="$2"
            shift 2
            ;;
        --mirror-root)
            # With --bundle: the transferred mirror directory holding the licence
            # (license/current.jwt) and the signed intel snapshot.
            AIRGAP_MIRROR_ROOT="$2"
            shift 2
            ;;
        --vibe-coding|--vibe)
            # Redundant with the default, but published agent plugins send it
            # on every install and the bootstrap forwards it, so it must keep
            # working.  It now means "wire the surface even on a host a wrapper
            # would otherwise treat as CI".
            VIBE_REQUESTED_FLAG="${VIBE_REQUESTED_FLAG:-$1}"
            shift
            ;;
        --no-vibe|--no-vibe-coding)
            # Scanner only: no daemon, no hooks, no MCP server, no skills.
            # Distinct from --no-auto-vibe/--no-baseline/--skip-vibe-baseline
            # below, which keep the surface and only suppress the baseline scan.
            NO_VIBE_REQUESTED_FLAG="${NO_VIBE_REQUESTED_FLAG:-$1}"
            shift
            ;;
        --agent)
            VIBE_REQUESTED_FLAG="${VIBE_REQUESTED_FLAG:-$1}"
            VIBE_AGENTS+=("$2")
            shift 2
            ;;
        --repo|--workspace)
            VIBE_WORKSPACE="$2"
            shift 2
            ;;
        --baseline|--baseline-scan)
            VIBE_REQUESTED_FLAG="${VIBE_REQUESTED_FLAG:-$1}"
            VIBE_RUN_BASELINE=true
            shift
            ;;
        --no-auto-vibe|--skip-vibe-baseline|--no-baseline)
            # Baseline-scan opt-out only. These say nothing about the surface:
            # the plugin's generated setup.sh passes --no-baseline on every run
            # and must keep getting the full surface, while a CI runner may pass
            # --no-vibe --no-baseline together and must keep getting neither.
            VIBE_RUN_BASELINE=false
            shift
            ;;
        --help|-h)
            echo "REACHABLE Installer"
            echo ""
            echo "Usage:"
            echo "  ./install.sh [OPTIONS]"
            echo ""
            echo "REACHABLE has one install mode. Every install gets the scanner AND the"
            echo "continuous surface: the local daemon, agent hooks, the MCP server, and"
            echo "the generated skills/rules. The skills loop is the product, so the"
            echo "component that delivers it is not an add-on."
            echo ""
            echo "Options:"
            echo "  --update, -u       Upgrade existing installation (backs up data)"
            echo "  --clean            Remove existing data before install"
            echo "  --uninstall        Remove REACHABLE from this machine: agent plugins, MCP"
            echo "                     server, daemon, and ~/.reachable including scan history"
            echo "                     and credentials. Asks first; --yes skips the question."
            echo "  --yes, -y          Answer yes to the --uninstall confirmation"
            echo "  --version, -v VER  Install specific version (e.g., 1.0.0b35)"
            echo "  --wheel, -w FILE   Install from local wheel file (skips download)"
            echo "  --dist-root DIR    Install from a local signed dist artifact directory"
            echo "  --dist-base-url URL"
            echo "                     Install from a signed dist artifact base URL"
            echo "  --no-vibe          Install the scanner ONLY: no daemon, no agent hooks,"
            echo "                     no MCP server, no generated skills. This exists for CI"
            echo "                     runners and other ephemeral, non-interactive hosts: a"
            echo "                     pipeline is single-shot, often containerised, and has"
            echo "                     no supervisor for a filesystem-watching daemon, so"
            echo "                     starting one there is waste at best and a hang risk at"
            echo "                     worst. On a developer machine it removes the product"
            echo "                     you installed REACHABLE for — do not reach for it there."
            echo "  --no-vibe-coding   Alias for --no-vibe"
            echo "  --vibe             Wire the continuous surface explicitly. This is already"
            echo "                     the default; pass it to force the surface on a host that"
            echo "                     a wrapper would otherwise treat as CI, and because every"
            echo "                     published agent plugin sends it."
            echo "  --vibe-coding      Alias for --vibe"
            echo "  --agent NAME       Restrict agent wiring to a specific agent (implies --vibe)"
            echo "  --repo DIR         Repo root to wire (defaults to the current repo)"
            echo "  --baseline         Run the initial baseline scan (implies --vibe)"
            echo "  --no-baseline      Skip the baseline scan; the surface is still installed."
            echo "                     This is NOT --no-vibe. Baseline scans are opt-in already,"
            echo "                     so this is a compatibility no-op on its own."
            echo "  --no-auto-vibe     Alias for --no-baseline"
            echo "  --skip-vibe-baseline"
            echo "                     Alias for --no-baseline"
            echo "  --list, -l         List available releases"
            echo "  --help, -h         Show this help"
            echo ""
            echo "  --no-vibe cannot be combined with --vibe, --vibe-coding, --agent, or"
            echo "  --baseline: those ask for the surface --no-vibe removes. The installer"
            echo "  exits 2 rather than picking a winner."
            echo ""
            echo "  This script does not inspect the environment to decide the surface."
            echo "  ${PUBLIC_INSTALL_URL} detects GITHUB_ACTIONS / GITLAB_CI / CI,"
            echo "  prints what it found, and forwards --no-vibe or --vibe here explicitly."
            echo ""
            echo "Examples:"
            echo "  curl -fsSL ${PUBLIC_INSTALL_URL} | bash                  # Fresh install, full surface"
            echo "  curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --no-vibe  # CI runner: scanner only"
            echo "  curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --list     # Show available versions"
            echo "  curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --update   # Upgrade with backup"
            echo "  curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --clean    # Clean install"
            echo "  curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --version 1.0.0b35"
            echo "  curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --agent codex"
            echo "  curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --baseline"
            echo "  REACHABLE_DIST_ROOT=/tmp/reachable-candidate ./install.sh --clean"
            echo "  curl -fsSL ${PUBLIC_INSTALL_URL} | REACHABLE_DIST_BASE_URL=https://example.test/reachable-candidate bash -s -- --clean"
            echo ""
            echo "Local checkout only (run from the reach-dist repo root):"
            echo "  ./install.sh --wheel ./file.whl"
            echo "  ./install.sh --no-vibe"
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

# Resolve the install surface once, after the whole argv has been read, so the
# result is independent of flag order. Contradictory flags abort; they are never
# resolved in favour of one of them.
if [[ -n "$NO_VIBE_REQUESTED_FLAG" && -n "$VIBE_REQUESTED_FLAG" ]]; then
    echo "Error: $NO_VIBE_REQUESTED_FLAG cannot be combined with $VIBE_REQUESTED_FLAG" >&2
    echo "  $VIBE_REQUESTED_FLAG asks for the continuous surface (daemon, agent hooks," >&2
    echo "  MCP server, generated skills). $NO_VIBE_REQUESTED_FLAG removes it." >&2
    echo "  Pass one or the other, not both." >&2
    echo "  (--no-baseline / --no-auto-vibe / --skip-vibe-baseline are a different" >&2
    echo "   thing: they only skip the baseline scan and combine freely with either.)" >&2
    exit 2
fi

if [[ -n "$NO_VIBE_REQUESTED_FLAG" ]]; then
    ENABLE_VIBE_CODING=false
    VIBE_SURFACE_REASON="$NO_VIBE_REQUESTED_FLAG"
elif [[ -n "$VIBE_REQUESTED_FLAG" ]]; then
    ENABLE_VIBE_CODING=true
    VIBE_SURFACE_REASON="$VIBE_REQUESTED_FLAG"
else
    ENABLE_VIBE_CODING=true
    VIBE_SURFACE_REASON="default"
fi

if [[ -n "${REACHABLE_DIST_ROOT:-}" && -n "${REACHABLE_DIST_BASE_URL:-}" ]]; then
    echo "Error: use either REACHABLE_DIST_ROOT/--dist-root or REACHABLE_DIST_BASE_URL/--dist-base-url, not both"
    exit 1
fi

if [[ -n "${LOCAL_WHEEL:-}" ]] && candidate_dist_source_enabled; then
    echo "Error: --wheel cannot be combined with candidate dist source options"
    exit 1
fi

if [[ -n "$AIRGAP_BUNDLE_INPUT" ]]; then
    if [[ -n "${LOCAL_WHEEL:-}" ]] || candidate_dist_source_enabled; then
        echo "Error: --bundle cannot be combined with --wheel, --dist-root or --dist-base-url"
        exit 1
    fi
    if [[ -f "$AIRGAP_BUNDLE_INPUT" ]]; then
        mkdir -p "${REACHABLE_TMP_ROOT:-${TMPDIR:-/tmp}}"
        _bundle_unpacked="$(mktemp -d "${REACHABLE_TMP_ROOT:-${TMPDIR:-/tmp}}/bundle.XXXXXX")"
        extract_bundle_archive "$AIRGAP_BUNDLE_INPUT" "$_bundle_unpacked" || exit 1
        AIRGAP_BUNDLE_INPUT="$_bundle_unpacked"
    fi
    if [[ ! -d "$AIRGAP_BUNDLE_INPUT" ]]; then
        echo "Error: --bundle $AIRGAP_BUNDLE_INPUT is neither a bundle archive nor a directory"
        exit 1
    fi
    if ! REACHABLE_AIRGAP_BUNDLE_ROOT="$(locate_bundle_root "$(cd "$AIRGAP_BUNDLE_INPUT" && pwd)")"; then
        echo "Error: no $BUNDLE_MANIFEST_NAME in $AIRGAP_BUNDLE_INPUT: not a release-chain air-gap bundle (AIRGAP-INSTALLER D36)"
        exit 1
    fi
    REACHABLE_DIST_ROOT="$REACHABLE_AIRGAP_BUNDLE_ROOT"
    if [[ -z "$AIRGAP_MIRROR_ROOT" || ! -d "$AIRGAP_MIRROR_ROOT" ]]; then
        echo "Error: --bundle needs --mirror-root <dir>: the transferred mirror directory with the licence and the intel snapshot"
        exit 1
    fi
    # Later side installs (doctor: semgrep, guarddog) re-verify THIS bundle
    # through the product and install from its wheelhouse.
    export REACHABLE_AIRGAP_BUNDLE="$REACHABLE_AIRGAP_BUNDLE_ROOT"
fi

selector_looks_like_version() {
    local selector="${1:-}"
    [[ "$selector" =~ ^v?[0-9]+(\.[0-9]+){2}([A-Za-z0-9._-]+)?$ ]]
}

resolve_version_from_release_tag() {
    local tag="$1"
    local encoded_tag
    local api_url
    local response

    encoded_tag="$(python3 - "$tag" <<'PY'
import sys
from urllib.parse import quote

print(quote(sys.argv[1], safe=""))
PY
)"
    api_url="https://api.github.com/repos/${REPO}/releases/tags/${encoded_tag}"

    if [[ -n "${RELEASES_API_TOKEN:-}" ]]; then
        response=$(github_curl -sL "$api_url")
    else
        response=$(curl -sL "$api_url")
    fi

    echo "$response" | python3 -c "
import json
import os
import re
import sys

data = json.load(sys.stdin)
if not isinstance(data, dict):
    sys.stderr.write('Error resolving release version: unexpected GitHub API response\\n')
    sys.exit(1)
if data.get('message') and not data.get('tag_name'):
    msg = str(data.get('message', 'unknown error'))
    has_token = bool(os.environ.get('GITHUB_TOKEN', '') or os.environ.get('MCP_GITHUB_TOKEN', ''))
    if 'rate limit' in msg.lower():
        if has_token:
            sys.stderr.write('Error: GitHub API rate limit exceeded even with GITHUB_TOKEN or MCP_GITHUB_TOKEN.\\n')
            sys.stderr.write('  Your token may be invalid or scoped incorrectly.\\n')
        else:
            sys.stderr.write('Error: GitHub API rate limit exceeded (unauthenticated).\\n')
            sys.stderr.write('  Fix option 1 - set a token and retry.\\n')
            sys.stderr.write('  Fix option 2 - wait about 1 hour for the rate limit to reset, then retry.\\n')
    else:
        sys.stderr.write('Error resolving release version for tag ' + sys.argv[1] + ': ' + msg + '\\n')
    sys.exit(1)

assets = data.get('assets') or []
for asset in assets:
    name = str(asset.get('name', '')).strip()
    match = re.match(r'^reachable-([^-]+)-.+\\.whl$', name)
    if match:
        print(match.group(1))
        sys.exit(0)

version = str(data.get('name', '')).strip()
if version and re.match(r'^v?[0-9]+(\\.[0-9]+){2}([A-Za-z0-9._-]+)?$', version):
    print(version.lstrip('v'))
    sys.exit(0)

sys.stderr.write('Error resolving release version for tag ' + sys.argv[1] + ': no reachable wheel assets found\\n')
sys.exit(1)
" "$tag" GITHUB_TOKEN="${GITHUB_TOKEN:-}" MCP_GITHUB_TOKEN="${MCP_GITHUB_TOKEN:-}"
}

apply_version_selection() {
    # --wheel mode doesn't need a version (extracted from wheel filename)
    if [[ -n "$LOCAL_WHEEL" ]]; then
        VERSION="local"
        WHEEL_VERSION="local"
        RELEASE_TAG="local"
    elif [[ -n "$CUSTOM_VERSION" ]]; then
        if selector_looks_like_version "$CUSTOM_VERSION"; then
            VERSION="${CUSTOM_VERSION#v}"
            WHEEL_VERSION="$VERSION"
            RELEASE_TAG="$(release_tag_for_version "$VERSION")"
        else
            RELEASE_TAG="$CUSTOM_VERSION"
            if candidate_dist_source_enabled; then
                VERSION=$(resolve_version_from_candidate_dist || true)
            else
                VERSION=$(resolve_version_from_release_tag "$RELEASE_TAG" || true)
            fi
            if [[ -z "$VERSION" ]]; then
                echo "Error: could not resolve wheel version for release tag $RELEASE_TAG"
                exit 1
            fi
            WHEEL_VERSION="$VERSION"
        fi
    else
        if candidate_dist_source_enabled; then
            VERSION=$(resolve_version_from_candidate_dist || true)
            if [[ -z "$VERSION" ]]; then
                echo "Error: candidate dist source requires --version or latest.json in the candidate artifact directory"
                exit 1
            fi
        else
            VERSION=$(resolve_version)
        fi
        if [[ -z "$VERSION" ]]; then
            echo "Error: could not resolve latest version from ${REPO}"
            exit 1
        fi
        WHEEL_VERSION="$VERSION"
        RELEASE_TAG="$(release_tag_for_version "$VERSION")"
    fi
}

apply_version_selection

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

# The distinct package names a vendor directory provides.
#
# Needed because the vendor dir is NOT always one wheel per package. macOS is
# the case that forced this: our own wheel is universal2, but psutil and
# ruamel.yaml.clib publish no universal2 wheel for cp314 -- only separate
# arm64 and x86_64 ones -- so the archive has to carry both and let pip choose.
# Installing the directory by glob instead makes pip try EVERY file, and the
# one for the other architecture is fatal:
#
#   ERROR: psutil-7.2.2-cp36-abi3-macosx_11_0_arm64.whl is not a supported
#          wheel on this platform
#
# Measured 2026-10-19 on an Intel macOS runner against b231. Naming the
# packages instead lets pip pick the wheel that fits, and still fails loudly
# when NONE fits -- which a "skip what doesn't match" loop would not.
_vendor_package_names() {
    local vendor_dir="$1" whl pkg
    for whl in "$vendor_dir"/*.whl; do
        [ -f "$whl" ] || continue
        pkg=$(basename "$whl" | sed 's/-[0-9].*//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
        echo "$pkg"
    done | sort -u
}

# Prove the vendor wheels we just installed can actually be imported.
#
# _retag_vendor_wheels above renames a CI-built `linux_<arch>` wheel to
# manylinux_2_17 so pip's resolver accepts it. That rename is a CLAIM about the
# binary's glibc floor, and nothing had ever checked it. CI built yara-python on
# ubuntu-24.04 (glibc 2.39), the rename said 2.17, pip believed the name, and
# the install finished green on python:3.14-slim-bookworm (glibc 2.36) with a
# yara.so that could not load:
#
#   ImportError: /lib/aarch64-linux-gnu/libc.so.6: version `GLIBC_2.38' not found
#
# guarddog imports yara unconditionally, so preflight then recorded guarddog as
# a failure and every `reachctl scan` refused to start -- with nothing on screen
# connecting that to an install that had reported success. Measured 2026-10-19
# on the published b230 aarch64 archive.
#
# An import is the only question that cannot be answered by a filename.
_verify_vendor_wheels_import() {
    local vendor_dir="$1"
    local py="$HOME/.reachable/venv/bin/python"
    local whl base mod err
    for whl in "$vendor_dir"/*.whl; do
        [ -f "$whl" ] || continue
        base=$(basename "$whl")
        case "$base" in
            # Only wheels whose module imports STANDALONE can be probed here:
            # vendor wheels go in before the dependency tree, so anything whose
            # import reaches outside its own wheel reports a missing sibling as
            # if it were a glibc failure.
            #
            # ruamel.yaml.clib is exactly that case and is deliberately absent:
            # its payload is the top-level _ruamel_yaml.so, whose Cython init
            # runs `init ruamel.yaml.clib._ruamel_yaml` and therefore needs the
            # pure-python ruamel.yaml parent that arrives two steps later. It is
            # also not the risk this probe exists for -- it comes from PyPI
            # already carrying a real manylinux tag, while yara-python is the
            # one built in CI whose tag we assign ourselves.
            yara_python-*)       mod="yara" ;;
            psutil-*)            mod="psutil" ;;
            *)                   continue ;;
        esac
        if ! err=$("$py" -c "import $mod" 2>&1); then
            print_error "Vendor wheel $base installed but cannot be imported:"
            print_error "  $(echo "$err" | tail -1)"
            print_error "This platform is below the wheel's real glibc floor."
            print_error "Report to: info@sthenosec.com"
            exit 1
        fi
    done
}

# Does the managed venv actually work, or does it only have the right version
# number? Called on the --update fast path, where nothing has been downloaded
# yet, so this probes what is ALREADY on disk rather than a vendor directory.
#
# Returns non-zero (i.e. "reinstall it") when:
#   * the .vendor-stamp is missing but the platform should have one -- an
#     install that lost its stamp also lost doctor's record of what is present;
#   * any package the stamp names cannot be imported by the venv python.
#
# Deliberately NOT a hardcoded module list: the stamp is the installer's own
# record of what it placed, so this cannot drift from what shipped.
_managed_venv_proves_itself() {
    local py="$HOME/.reachable/venv/bin/python"
    local stamp="$HOME/.reachable/venv/.vendor-stamp"
    local pkg mod

    [[ -x "$py" ]] || return 1

    if [[ ! -f "$stamp" ]]; then
        # No stamp. Either this install never had vendor wheels, or it lost the
        # record. Both are worth repairing on an explicit --update, and the
        # repair is the ordinary install path.
        print_info "no vendor stamp found under the managed venv"
        return 1
    fi

    while read -r pkg; do
        [[ -n "$pkg" ]] || continue
        # Package name -> import name. Only the ones whose spelling differs
        # need a case; everything else imports under its own name with
        # dashes normalised to underscores.
        case "$pkg" in
            yara-python) mod="yara" ;;
            # The wheel's top_level.txt is `_ruamel_yaml` (plus the `ruamel`
            # namespace). `ruamel_yaml_clib` is not a module, so the default
            # spelling failed every healthy Linux venv and --update deleted it.
            ruamel-yaml-clib) mod="_ruamel_yaml" ;;
            *)           mod="${pkg//-/_}" ;;
        esac
        if ! env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH \
             "$py" -c "import $mod" >/dev/null 2>&1; then
            print_info "vendor package '$pkg' is stamped but '$mod' does not import"
            return 1
        fi
    done < "$stamp"

    return 0
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
    log_event "HEADER $1"
}

print_step() {
    echo -e "\n${CYAN}▶${NC} ${BOLD}$1${NC}"
    log_event "STEP $1"
}

print_ok() {
    echo -e "  ${GREEN}✓${NC} $1"
    log_event "OK $1"
}

print_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    log_event "WARN $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
    log_event "ERROR $1"
}

print_info() {
    echo -e "  ${DIM}$1${NC}"
}

timestamp_utc() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

epoch_seconds() {
    date +%s
}

log_event() {
    if [[ -n "${INSTALL_LOG:-}" ]]; then
        printf '[%s] %s\n' "$(timestamp_utc)" "$*" >> "$INSTALL_LOG"
    fi
}

setup_install_log() {
    mkdir -p "$REACHABLE_INSTALL_LOG_DIR"
    if [[ -z "${INSTALL_LOG:-}" ]]; then
        local stamp
        stamp="$(date -u +%Y%m%dT%H%M%SZ)"
        INSTALL_LOG="$REACHABLE_INSTALL_LOG_DIR/install-${stamp}-$$.log"
    fi
    touch "$INSTALL_LOG"
    chmod 600 "$INSTALL_LOG" 2>/dev/null || true
    exec > >(tee -a "$INSTALL_LOG") 2>&1
    print_info "Install log: $INSTALL_LOG"
}

configure_venv_pip_config() {
    local venv_dir="$HOME/.reachable/venv"
    mkdir -p "$venv_dir"
    cat > "$venv_dir/pip.conf" <<EOF
[global]
timeout = ${REACHABLE_PIP_TIMEOUT}
retries = ${REACHABLE_PIP_RETRIES}
disable-pip-version-check = true
progress-bar = ${REACHABLE_PIP_PROGRESS_BAR}
EOF
    if bundle_mode_enabled; then
        # Every pip call in this venv is offline by construction: the bundle's
        # wheelhouse is the only index, now and for later side installs.
        printf 'no-index = true\nfind-links = %s/wheelhouse\n' "${REACHABLE_AIRGAP_BUNDLE_ROOT%/}" >> "$venv_dir/pip.conf"
    fi
    print_info "Pip config: $venv_dir/pip.conf"
}

managed_reachable_version() {
    local venv_python="$HOME/.reachable/venv/bin/python"
    if [[ ! -x "$venv_python" ]]; then
        return 1
    fi
    "$venv_python" - <<'PY' 2>/dev/null
from importlib import metadata
try:
    print(metadata.version("reachable"))
except metadata.PackageNotFoundError:
    raise SystemExit(1)
PY
}

uninstall_managed_reachable() {
    local venv_python="$HOME/.reachable/venv/bin/python"
    if [[ ! -x "$venv_python" ]]; then
        return 0
    fi
    "$venv_python" -u -m pip uninstall reachable -y
}

run_pip_with_retries() {
    local label="$1"
    local max_attempts="$2"
    shift 2
    local display_label="$label"
    if [[ "$REACHABLE_INSTALLER_AGENT_SETUP" == "1" ]]; then
        case "$label" in
            "Upgrading pip in managed venv") display_label="Preparing Python environment" ;;
            "Installing hash-pinned dependencies") display_label="Installing runtime dependencies" ;;
            "Installing vendor wheels") display_label="Installing platform wheels" ;;
            "Installing REACHABLE wheel") display_label="Installing reachable" ;;
        esac
    fi

    mkdir -p "$REACHABLE_TMP_ROOT"

    local attempt
    local rc=0
    local attempt_log
    attempt_log="$(mktemp "$REACHABLE_TMP_ROOT/pip-install.XXXXXX")"

    for attempt in $(seq 1 "$max_attempts"); do
        if [[ "$max_attempts" -gt 1 ]]; then
            print_info "$display_label (attempt $attempt/$max_attempts)"
        else
            print_info "$display_label"
        fi

        : > "$attempt_log"
        set +e
        local started_at
        local elapsed
        started_at="$(epoch_seconds)"
        log_event "PIP start label=\"$label\" attempt=$attempt/$max_attempts"
        if [[ "$REACHABLE_PIP_VERBOSE" == "1" ]]; then
            PYTHONUNBUFFERED=1 \
                PIP_CONFIG_FILE="$HOME/.reachable/venv/pip.conf" \
                "$@" 2>&1 | tee "$attempt_log"
            rc=${PIPESTATUS[0]}
        else
            local pip_pid
            local now
            local next_progress
            next_progress=$((started_at + REACHABLE_INSTALL_PROGRESS_INTERVAL))
            PYTHONUNBUFFERED=1 \
                PIP_CONFIG_FILE="$HOME/.reachable/venv/pip.conf" \
                "$@" > "$attempt_log" 2>&1 &
            pip_pid=$!
            while jobs -pr | grep -qx "$pip_pid"; do
                sleep 1
                now="$(epoch_seconds)"
                if [[ "$REACHABLE_INSTALL_PROGRESS_INTERVAL" -gt 0 && "$now" -ge "$next_progress" ]]; then
                    elapsed=$((now - started_at))
                    print_info "$display_label still running (${elapsed}s elapsed; log: $INSTALL_LOG)"
                    log_event "PIP progress label=\"$label\" attempt=$attempt/$max_attempts elapsed=${elapsed}s"
                    next_progress=$((now + REACHABLE_INSTALL_PROGRESS_INTERVAL))
                fi
            done
            wait "$pip_pid"
            rc=$?
            if [[ -n "${INSTALL_LOG:-}" ]]; then
                {
                    echo ""
                    echo "=== pip output: $label attempt $attempt/$max_attempts rc=$rc ==="
                    cat "$attempt_log"
                } >> "$INSTALL_LOG"
            fi
        fi
        set -e
        elapsed=$(($(epoch_seconds) - started_at))
        log_event "PIP end label=\"$label\" attempt=$attempt/$max_attempts rc=$rc elapsed=${elapsed}s"

        if [[ $rc -eq 0 ]]; then
            return 0
        fi

        if [[ "$attempt" -lt "$max_attempts" ]]; then
            print_warn "$display_label failed with exit $rc; retrying in ${REACHABLE_DOWNLOAD_RETRY_DELAY} seconds"
            sleep "$REACHABLE_DOWNLOAD_RETRY_DELAY"
        fi
    done

    print_error "$display_label failed after $max_attempts attempts (exit $rc)"
    tail -30 "$attempt_log" | sed 's/^/    /'
    return "$rc"
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
    local path_line='export PATH="$HOME/.reachable/venv/bin:$PATH"'
    local marker_line="# Added by REACHABLE installer"
    local rc_file
    local path_count
    local tmp_file

    case ":$PATH:" in
        *":$reach_path:"*) ;;
        *) export PATH="$reach_path:$PATH" ;;
    esac

    rc_file="$(_shell_rc_path)"
    PATH_CONFIG_TARGET="$rc_file"
    mkdir -p "$(dirname "$rc_file")"
    touch "$rc_file"

    path_count=$({ grep -Fx "$path_line" "$rc_file" 2>/dev/null || true; } | wc -l | tr -d ' ')
    if [[ "$path_count" == "1" ]]; then
        PATH_CONFIG_STATUS="already-configured"
        return
    fi

    tmp_file=$(mktemp "${TMPDIR:-/tmp}/reachable-path.XXXXXX")
    awk -v marker="$marker_line" -v path_line="$path_line" '
        $0 == marker { next }
        $0 == path_line { next }
        { print }
    ' "$rc_file" > "$tmp_file"
    cat "$tmp_file" > "$rc_file"
    rm -f "$tmp_file"

    {
        echo ""
        echo "$marker_line"
        echo "$path_line"
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
    
    # Python version. Prefer an explicit PYTHON=... override, then modern
    # python3.x binaries, because macOS can leave /usr/bin/python3 on 3.9.
    if ! PY_BIN="$(resolve_python_bin)"; then
        print_error "Python 3.11+ not found"
        exit 1
    fi
    
    # Check python3-venv is available (common missing package on Debian/Ubuntu ARM64)
    if ! "$PY_BIN" -c "import venv" 2>/dev/null; then
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
    
    PY_VERSION=$("$PY_BIN" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
    PY_ARCH="$("$PY_BIN" -c "import platform; print(platform.machine())" 2>/dev/null || echo unknown)"
    
    if [[ "$PY_MAJOR" -lt 3 ]] || [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 11 ]]; then
        print_error "Python 3.11+ required (found $PY_VERSION)"
        exit 1
    fi

    if [[ "$OS" == "darwin" ]]; then
        HW_ARM64="$(sysctl -in hw.optional.arm64 2>/dev/null || echo 0)"
        PROC_TRANSLATED="$(sysctl -in sysctl.proc_translated 2>/dev/null || echo 0)"
        if [[ "$HW_ARM64" == "1" && "$PY_ARCH" == "x86_64" ]]; then
            print_warn "Intel/Rosetta Python detected on Apple Silicon: $PY_BIN"
            print_warn "REACHABLE ships universal2 wheels, but native Python is more reliable."
            print_warn "Recommended: install/use /opt/homebrew/bin/python3, then rerun the installer."
        elif [[ "$PROC_TRANSLATED" == "1" ]]; then
            print_warn "Installer appears to be running under Rosetta translation."
            print_warn "Recommended: rerun from a native ARM64 terminal with /opt/homebrew/bin/python3."
        fi
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
    
    if INSTALLED_VERSION="$(managed_reachable_version)"; then
        print_step "Existing installation detected"
        print_info "Installed version: $INSTALLED_VERSION"
        print_info "Target version:    $WHEEL_VERSION"
        
        if [[ "$INSTALLED_VERSION" == "$WHEEL_VERSION" && -x "$HOME/.reachable/venv/bin/reachctl" && "$CLEAN_DATA" != true ]]; then
            # Version match is not enough. The venv python is a copied binary
            # tied to the CPython that created it. CI's setup-python can make
            # a stale copy start via LD_LIBRARY_PATH, then scan children die
            # without that path. Prove it under a clean env.
            if env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH \
                 "$HOME/.reachable/venv/bin/python" -c 'import sys' >/dev/null 2>&1; then
                # "Already current" is a statement about the VERSION NUMBER. It
                # is not a statement about whether the install works, and this
                # branch used to say "verifying setup" while verifying nothing
                # that could catch a broken venv. Measured 2026-10-19 on macOS:
                # with yara-python removed and .vendor-stamp deleted -- the
                # exact state a b230 macOS install is in -- `--update` printed
                # "already current; verifying setup" and left every scan
                # refusing. The cross-version path is fine because it takes the
                # full install branch; this only bites a host broken AT the
                # latest version, which is precisely when someone runs --update
                # to repair it.
                #
                # So under --update the venv must now PROVE itself. The stamp is
                # the installer's own record of which vendor packages it placed,
                # so it is the honest thing to check against -- no guessing about
                # which platforms carry which native wheel.
                if [[ "$UPDATE_MODE" == true ]] \
                   && ! _managed_venv_proves_itself; then
                    print_warn "runtime reports $INSTALLED_VERSION but does not pass verification; reinstalling in place"
                else
                    SKIP_RUNTIME_INSTALL=true
                    if [[ "$REACHABLE_INSTALLER_AGENT_SETUP" == "1" ]]; then
                        print_ok "reachable runtime is already current; venv verified"
                    else
                        print_ok "REACHABLE runtime is already current; venv verified"
                    fi
                    return
                fi
            else
                print_warn "existing venv python cannot start on this interpreter; rebuilding"
            fi
            rm -rf "$HOME/.reachable/venv"
        fi

        if [[ "$UPDATE_MODE" == true ]]; then
            # Updates are in-place. Runtime assets such as scanner DBs, tools,
            # and venvs are reproducible and must not be copied into timestamped
            # backups; Grype alone is ~1.7GB.
            print_info "Update mode: preserving data in place; no backup copy created"

            # Clear AI verdict caches on upgrade — Enzo prompts and AI
            # discovery prompts can change between versions; stale entries
            # served by the fast-path cache lookup would mask new behavior
            # (b76b regression: 100% cache hit served pre-dp_ctx verdicts).
            # ai-cache.db is also auto-wiped on AI_CACHE_SCHEMA_VERSION_INT
            # bumps inside init_schema(); this is belt-and-suspenders and
            # additionally handles ai-discovery.json which has no
            # schema-version mechanism.
            print_step "Clearing AI verdict caches (prompts may have changed)"
            find "$HOME/.reachable/scans" -name "ai-cache.db" -delete 2>/dev/null || true
            find "$HOME/.reachable/scans" -name "ai-discovery.json" -delete 2>/dev/null || true
            print_ok "AI caches cleared — next scan will rebuild fresh verdicts"
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
        local refresh_install_log=false
        if [[ -n "${INSTALL_LOG:-}" && "$INSTALL_LOG" == "$HOME/.reachable/"* ]]; then
            refresh_install_log=true
        fi
        print_step "Removing existing data (--clean)"
        rm -rf "$HOME/.reachable"
        if [[ "$refresh_install_log" == true ]]; then
            setup_install_log
        fi
        print_ok "Removed ~/.reachable"
    fi
}

# -----------------------------------------------------------------------------
# Release trust root
# -----------------------------------------------------------------------------
# cosign is OUT of the install path (docs/design/INSTALLER-ATTESTATION.md,
# items 8 + 10.1). It stays in CI — every release still ships .cosign.bundle
# sidecars and verify-wheel.sh remains the manual audit path — but nothing
# here downloads, installs, or consults it. What authenticates a release is
# the dual-signed manifest:
#
#   this pinned fingerprint  ->  root-signed key-list.json
#                              ->  reachable-signed-manifest.json
#                                 (all_of[release-ecdsa-p384,
#                                        release-mldsa-87])
#                              ->  sha384 of every artifact in it
#
# The fingerprint is SHA-384 over the enrolled ROOT public keys. It changes
# only if the root set changes — a new release signing key is a key-list
# version, not a re-pin. A mismatch is never routine: treat it as compromise.
REACHABLE_ROOT_FINGERPRINT='kvQtc1UxbGgVbWqY9c2LJhmu1LPkiZrUToBo2rhf3/LWnMFn7UIZuI0HilEmrvIC'

# Verifies what the host's own openssl can: the P-384 root signature on the
# key list and the P-384 manifest signature. That is half of each all_of
# policy — enough to authenticate the channel through which the ML-DSA
# verifier (cryptography) then arrives hash-pinned, which is exactly the
# bootstrap the design's §7.2 names. The FULL all_of check runs after, in
# verify_release_manifest.py, and nothing below trusts this half alone.
_bootstrap_openssl_verify() {
    # Runs in the download dir. Writes .trust/ files, prints nothing on
    # success. Returns nonzero on any failure.
    "$PY_BIN" - "$REACHABLE_ROOT_FINGERPRINT" <<'BOOTSTRAP_PY'
import base64, hashlib, json, pathlib, shutil, subprocess, sys

fingerprint = sys.argv[1]
d = pathlib.Path(".")
t = d / ".trust"
t.mkdir(exist_ok=True)

def die(msg):
    print(f"bootstrap verify: {msg}", file=sys.stderr)
    sys.exit(2)

if not shutil.which("openssl"):
    die("openssl not found — cannot verify the P-384 signature half (no verifier obtainable)")

kl_raw = (d / "key-list.json").read_bytes()
kl = json.loads(kl_raw)
# RECOMPUTE the fingerprint from the root keys this list names; never compare
# the list's own claim. Comparing the claimed field let any key list that
# copied the published string pass, signed by whatever roots it named. Same
# rule as reachable/artifacts/key_list.py::load_and_verify.
ROOT_ROLES = ("root-ecdsa-p384", "root-mldsa-87")
roots = [k for k in kl.get("keys") or [] if k.get("role") in ROOT_ROLES]
if not roots:
    die("key list names no root keys")
root_digests = sorted(hashlib.sha384(base64.b64decode(k["pubkey"])).hexdigest() for k in roots)
recomputed = base64.b64encode(
    hashlib.sha384("\n".join(root_digests).encode("ascii")).digest()).decode("ascii")
if recomputed != fingerprint:
    die("key-list root keys do not match the pinned fingerprint")
if kl.get("root_fingerprint") != recomputed:
    die("key-list states a root fingerprint that does not match its own keys")

def der_int(x):
    b = x.to_bytes((x.bit_length() + 7) // 8 or 1, "big")
    if b[0] & 0x80:
        b = b"\x00" + b
    return b"\x02" + bytes([len(b)]) + b

def raw_to_der(sig):
    half = len(sig) // 2
    body = der_int(int.from_bytes(sig[:half], "big")) + \
           der_int(int.from_bytes(sig[half:], "big"))
    return b"\x30" + bytes([len(body)]) + body

def pem_from_spki_b64(b64):
    der = base64.b64decode(b64)
    return ("-----BEGIN PUBLIC KEY-----\n"
            + base64.b64encode(der).decode()
            + "\n-----END PUBLIC KEY-----\n")

def openssl_verify(pub_pem, sig_der, msg):
    p = t / "pub.pem"; s = t / "sig.der"
    p.write_text(pub_pem); s.write_bytes(sig_der)
    r = subprocess.run(
        ["openssl", "dgst", "-sha384", "-verify", str(p), "-signature", str(s), msg],
        capture_output=True)
    return r.returncode == 0

# 1. At least one P-384 root signature must verify over the key list.
roots_p384 = [k for k in kl["keys"] if k["role"] == "root-ecdsa-p384"]
ok = False
for k in roots_p384:
    sig_path = d / f"key-list.{k['key_id']}.sig"
    if not sig_path.is_file():
        continue
    sig = sig_path.read_bytes()
    if len(sig) in (96, 64, 132) and sig[0] != 0x30:
        sig = raw_to_der(sig)
    if openssl_verify(pem_from_spki_b64(k["pubkey"]), sig, "key-list.json"):
        ok = True
        break
if not ok:
    die("no P-384 root signature verifies the key list")

# 2. The release P-384 signature must verify over the manifest.
rel = [k for k in kl["keys"] if k["role"] == "release-ecdsa-p384"]
if not rel:
    die("key list names no release-ecdsa-p384 key")
mf_sig = (d / "reachable-signed-manifest.json.p384.sig").read_bytes()
if not openssl_verify(pem_from_spki_b64(rel[0]["pubkey"]), mf_sig,
                      "reachable-signed-manifest.json"):
    die("release manifest P-384 signature does not verify")

# 3. The manifest now authenticates digests: the verifier script and
#    constraints.txt must match before either is trusted.
manifest = json.loads((d / "reachable-signed-manifest.json").read_text())
digests = {a["name"]: a["sha384"] for a in manifest["artifacts"]}
for name in ("verify_release_manifest.py", "constraints.txt"):
    want = digests.get(name)
    if want is None:
        die(f"{name} is not bound by the manifest")
    got = hashlib.sha384((d / name).read_bytes()).hexdigest()
    if got != want:
        die(f"sha384 mismatch on {name}")
BOOTSTRAP_PY
}


# -----------------------------------------------------------------------------
# Download & Install
# -----------------------------------------------------------------------------
download_and_install() {
    if [[ "$SKIP_RUNTIME_INSTALL" == true ]]; then
        return
    fi

    # If local wheel provided, use it directly
    if [[ -n "$LOCAL_WHEEL" ]]; then
        print_step "Installing from local wheel"
        
        if [[ ! -f "$LOCAL_WHEEL" ]]; then
            print_error "Wheel file not found: $LOCAL_WHEEL"
            exit 1
        fi
        
        print_info "File: $LOCAL_WHEEL"
        
        # Uninstall previous managed version
        if managed_reachable_version &> /dev/null; then
            print_step "Removing previous installation"
            uninstall_managed_reachable || true
            print_ok "Previous version removed"
        fi
        
        # Install into venv
        print_step "Installing reachable"
        "$PY_BIN" -m venv "$HOME/.reachable/venv"
        configure_venv_pip_config
        run_pip_with_retries "Upgrading pip in managed venv" "$REACHABLE_PIP_ATTEMPTS" \
            "$HOME/.reachable/venv/bin/python" -u -m pip install --upgrade pip

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
            # Intentional word-splitting: one argument per package name.
            # shellcheck disable=SC2046
            if ! run_pip_with_retries "Installing vendor wheels" "$REACHABLE_PIP_ATTEMPTS" \
                "$HOME/.reachable/venv/bin/python" -u -m pip install \
                    --no-deps --force-reinstall --no-index \
                    --find-links "$WHEEL_DIR/vendor/" \
                    $(_vendor_package_names "$WHEEL_DIR/vendor"); then
                print_error "Vendor wheel install failed — aborting"
                exit 1
            fi
            _verify_vendor_wheels_import "$WHEEL_DIR/vendor"
        fi

        # Install the main wheel.  --find-links lets pip resolve any remaining
        # dependencies; --only-binary for each vendor package prevents fallback
        # to source builds when no compiler is present.
        # Intentional word-splitting for optional pip flags.
        # shellcheck disable=SC2086,SC2046
        if ! run_pip_with_retries "Installing REACHABLE wheel dependencies" "$REACHABLE_PIP_ATTEMPTS" \
            "$HOME/.reachable/venv/bin/python" -u -m pip install \
            $VENDOR_FIND_LINKS \
            $(_vendor_only_binary_flags "$WHEEL_DIR/vendor") \
            "$LOCAL_WHEEL"; then
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
    
    # Remote/candidate install - download signed artifacts
    print_step "Downloading wheel"
    
    mkdir -p "$REACHABLE_TMP_ROOT"
    DOWNLOAD_DIR=$(mktemp -d "$REACHABLE_TMP_ROOT/install.XXXXXX")
    cd "$DOWNLOAD_DIR"
    
    if [[ -n "${REACHABLE_DIST_ROOT:-}" ]]; then
        print_info "Candidate dist root: $REACHABLE_DIST_ROOT"
    elif [[ -n "${REACHABLE_DIST_BASE_URL:-}" ]]; then
        print_info "Candidate dist base URL: ${REACHABLE_DIST_BASE_URL%/}"
    else
        print_info "Repository: github.com/$REPO"
        print_info "Release:    $RELEASE_TAG"
    fi
    print_info "File:       $WHEEL_FILE"
    
    if ! download_dist_artifact "Downloading REACHABLE wheel" "$WHEEL_FILE" "$WHEEL_FILE"; then
        print_error "Download failed"
        echo ""
        echo "  Source: $(dist_artifact_source "$WHEEL_FILE")"
        echo "  Possible causes:"
        echo "    • Release $RELEASE_TAG not yet available"
        echo "    • Wheel for Python $PY_VERSION / $PLATFORM_TAG not available"
        echo ""
        echo "  Contact: info@sthenosec.com"
        exit 1
    fi
    
    print_ok "Downloaded successfully"

    # ── Release manifest verification (replaces cosign; see the trust-root
    #    comment block above). One manifest binds every artifact by SHA-384
    #    and carries both KMS signatures; the key list that authenticates
    #    those signatures is itself root-signed and chains to the pinned
    #    fingerprint. Any failure is a hard stop — no flag bypasses it.
    print_step "Verifying release"

    for f in key-list.json \
             reachable-signed-manifest.json \
             reachable-signed-manifest.json.p384.sig \
             reachable-signed-manifest.json.mldsa87.sig \
             verify_release_manifest.py \
             constraints.txt; do
        if ! download_dist_artifact "Downloading $f" "$f" "$f"; then
            print_error "Could not fetch $f — aborting (supply chain risk)"
            print_info "Source: $(dist_artifact_source "$f")"
            print_info "Every release MUST publish the signed manifest, the key list that"
            print_info "authenticates it, and the verifier. If missing, the release may"
            print_info "be compromised."
            exit 1
        fi
    done

    # Root signatures are named key-list.<key_id>.sig; enumerate them from the
    # key list itself so a rotated or added root needs no installer change.
    KEY_SIGS=()
    while IFS= read -r sig_name; do
        [[ -n "$sig_name" ]] || continue
        if ! download_dist_artifact "Downloading $sig_name" "$sig_name" "$sig_name"; then
            print_error "Could not fetch $sig_name — aborting (supply chain risk)"
            exit 1
        fi
        KEY_SIGS+=("$sig_name")
    done < <("$PY_BIN" -c '
import json
doc = json.load(open("key-list.json"))
print("\n".join(
    "key-list." + k["key_id"] + ".sig"
    for k in doc["keys"] if k["role"].startswith("root")))
')
    if [[ ${#KEY_SIGS[@]} -eq 0 ]]; then
        print_error "key-list.json names no root signatures — aborting"
        exit 1
    fi

    # Vendor wheels: fetched now so the manifest check covers the archive too.
    #
    # This was `if [[ "$OS" == "linux" ]]` until 2026-10-19, and $OS is "darwin"
    # on a Mac, so macOS never fetched the archive. release.yml has published
    # vendor-cp3XX-macosx_universal2.tar.gz since 3230df97 (2026-10-18) and the
    # installer still ignored it: measured on a clean b230 install through the
    # public one-liner, macOS + Python 3.14 ended with no yara-python, guarddog
    # unimportable, and every `reachctl scan` refusing to start.
    #
    # The archive's own name differs from $PLATFORM_TAG on macOS -- the wheel is
    # tagged macosx_11_0_universal2, the vendor archive is macosx_universal2
    # (release.yml:499) -- so lifting the OS gate alone would have 404'd and
    # fallen into the same silence.
    VENDOR_PLATFORM_TAG="$PLATFORM_TAG"
    if [[ "$OS" == "darwin" ]]; then
        VENDOR_PLATFORM_TAG="macosx_universal2"
    fi

    HAS_VENDOR_REMOTE=false
    VENDOR_ARCHIVE="vendor-${PY_TAG}-${VENDOR_PLATFORM_TAG}.tar.gz"
    if bundle_mode_enabled; then
        # The bundle's wheelhouse carries the whole binary closure for this
        # platform, side installs included, so there is no separate archive.
        print_info "Air-gap bundle: binaries come from its wheelhouse"
    elif download_dist_artifact "Downloading vendor wheels" "$VENDOR_ARCHIVE" "$VENDOR_ARCHIVE"; then
        HAS_VENDOR_REMOTE=true
    else
        # Not optional, and not survivable. The archive carries yara-python,
        # which guarddog imports unconditionally and which publishes no cp314
        # wheel on any platform; without it preflight records guarddog as a
        # failure and the scanner refuses to start. Continuing here produced an
        # install that looked successful and could not scan -- the failure has
        # to land at install time, where the cause is still on screen.
        print_error "Vendor wheels missing for this platform: $VENDOR_ARCHIVE"
        print_error "Expected in release $WHEEL_VERSION. Report to: info@sthenosec.com"
        exit 1
    fi

    # P-384 half via the host's own openssl: authenticates the key list, the
    # manifest, and through it the digests of the verifier and constraints.
    if ! _bootstrap_openssl_verify; then
        print_error "Release verification FAILED — aborting"
        print_info "The manifest or key list was not signed by Sthenos Security, or was"
        print_info "tampered with in transit. Do NOT retry against a different mirror"
        print_info "unless you trust it — and if this persists, report to info@sthenosec.com"
        exit 1
    fi
    print_ok "P-384 signature verified (openssl)"

    # Uninstall previous managed version
    if managed_reachable_version &> /dev/null; then
        print_step "Removing previous installation"
        uninstall_managed_reachable || true
        print_ok "Previous version removed"
    fi

    # Install into venv
    if [[ "$REACHABLE_INSTALLER_AGENT_SETUP" == "1" ]]; then
        print_step "Installing reachable v$VERSION"
    else
        print_step "Installing REACHABLE v$VERSION"
    fi
    if ! "$PY_BIN" -m venv "$HOME/.reachable/venv" 2>&1; then
        print_error "Failed to create virtual environment"
        if [[ "$OS" == "linux" ]]; then
            echo "  Try: sudo apt install python3-venv python3-dev"
        fi
        exit 1
    fi
    configure_venv_pip_config
    if ! bundle_mode_enabled; then
        run_pip_with_retries "Upgrading pip in managed venv" "$REACHABLE_PIP_ATTEMPTS" \
            "$HOME/.reachable/venv/bin/python" -u -m pip install --upgrade pip
    fi

    # constraints.txt was fetched with the trust artifacts and its sha384 was
    # already checked against the manifest by _bootstrap_openssl_verify. Its
    # hashes now authenticate everything pip touches.
    CONSTRAINTS_FLAG=""
    CONSTRAINTS_MODE="none"
    if ! grep -q "\-\-hash=" constraints.txt 2>/dev/null; then
        print_error "constraints.txt is not hash-pinned — aborting (supply chain risk)"
        print_info "Every dependency entry MUST include --hash."
        exit 1
    fi

    # The full all_of verification needs `cryptography` (ML-DSA-87 has no
    # openssl path). Install it hash-pinned from the manifest-authenticated
    # constraints — the P-384-authenticated channel delivering the ML-DSA
    # verifier, exactly the bootstrap §7.2 describes. No cryptography, no
    # install: §5.4 says a host that cannot verify hard-stops.
    #
    # As a REQUIREMENTS file cut from those constraints, not `-c constraints.txt
    # cryptography`: pip before 26 ignores hashes in a constraints file and
    # refuses the unpinned name in --require-hashes mode. A bundle install
    # keeps the enclave image's own pip (no upgrade without an index), so the
    # constraints form failed every air-gap install. If cryptography ever
    # gains a dependency not listed here, pip stops on its missing hash.
    write_verifier_requirements constraints.txt > verifier-requirements.txt
    if ! grep -q "^cryptography==" verifier-requirements.txt; then
        print_error "constraints.txt pins no cryptography — cannot install the signature verifier"
        exit 1
    fi
    if ! run_pip_with_retries "Installing signature verifier" "$REACHABLE_PIP_ATTEMPTS" \
        "$HOME/.reachable/venv/bin/python" -u -m pip install \
            --require-hashes -r verifier-requirements.txt; then
        print_error "Could not install the signature verifier — aborting"
        print_info "A host that cannot verify a required signature hard-stops."
        exit 1
    fi

    # FULL verification: every root signature on the key list, both release
    # signatures on the manifest, and the sha384 of every artifact we will
    # act on. This is the gate — nothing above it was trusted alone.
    VERIFY_ARTIFACTS=("$WHEEL_FILE" constraints.txt)
    if [[ "$HAS_VENDOR_REMOTE" == true ]]; then
        VERIFY_ARTIFACTS+=("$VENDOR_ARCHIVE")
    fi
    VERIFY_ARGS=(
        --expected-fingerprint "$REACHABLE_ROOT_FINGERPRINT"
        --key-list key-list.json
        --manifest reachable-signed-manifest.json
        --manifest-sig reachable-signed-manifest.json.p384.sig
        --manifest-sig reachable-signed-manifest.json.mldsa87.sig
    )
    for s in "${KEY_SIGS[@]}"; do
        VERIFY_ARGS+=(--key-sig "$s")
    done
    if bundle_mode_enabled; then
        # The bundle manifest binds the WHOLE tree: every file by relative
        # path, nothing unlisted, and only for the air-gap bundle's scope.
        VERIFY_ARGS+=(--artifact-root "$REACHABLE_AIRGAP_BUNDLE_ROOT" --expected-scope "$BUNDLE_SCOPE")
    else
        for a in "${VERIFY_ARTIFACTS[@]}"; do
            VERIFY_ARGS+=(--artifact "$a")
        done
    fi
    if ! "$HOME/.reachable/venv/bin/python" verify_release_manifest.py "${VERIFY_ARGS[@]}"; then
        print_error "Release verification FAILED — aborting"
        print_info "The release was not signed by both Sthenos Security release keys, or"
        print_info "an artifact does not match the signed manifest. Report to"
        print_info "info@sthenosec.com if this persists."
        exit 1
    fi
    print_ok "Release verified (P-384 + ML-DSA-87, manifest bound)"

    CONSTRAINTS_MODE="hash"
    print_ok "Dependency constraints verified (hash-pinned, manifest-bound)"

    # Vendor archive was downloaded with the trust artifacts and its sha384
    # verified against the manifest above. Unpack it.
    if [[ "$HAS_VENDOR_REMOTE" == true ]]; then
        mkdir -p vendor/
        tar xzf "$VENDOR_ARCHIVE" -C vendor/
        if ls vendor/*.whl 1>/dev/null 2>&1; then
            _retag_vendor_wheels vendor/
            print_ok "Vendor wheels prepared (built and signed in CI)"
        else
            # An archive that unpacks to no wheels is a broken release, not a
            # platform without vendor wheels. Flipping HAS_VENDOR_REMOTE back
            # to false here is the same silence the OS gate above produced.
            print_error "Vendor archive $VENDOR_ARCHIVE contains no wheels — aborting"
            exit 1
        fi
    fi

    # ── Pre-install vendor wheels ──────────────────────────────────────────
    # Vendor wheels contain C extensions (yara-python, psutil, ruamel-yaml-clib)
    # built in CI.  Some are deps of guarddog, not reachable — so --find-links
    # alone won't install them (pip only resolves deps of the main package).
    # Install ALL vendor wheels explicitly first, then install the main wheel.
    if [[ "$HAS_VENDOR_REMOTE" == true ]]; then
        # F-009b: vendor wheel install failure is meaningful — do not swallow (CWE-755)
        # Intentional word-splitting: one argument per package name.
        # shellcheck disable=SC2046
        if ! run_pip_with_retries "Installing vendor wheels" "$REACHABLE_PIP_ATTEMPTS" \
            "$HOME/.reachable/venv/bin/python" -u -m pip install \
                --no-deps --force-reinstall --no-index \
                --find-links vendor/ \
                $(_vendor_package_names vendor); then
            print_error "Vendor wheel install failed — aborting"
            exit 1
        fi
        _verify_vendor_wheels_import vendor/
    fi

    # Hash-checking mode applies to every requirement being installed. The
    # Reachable wheel is a local, already manifest-verified artifact, so
    # install dependencies from constraints first, then install the wheel with
    # --no-deps. This keeps dependency artifact hashes enforced without making
    # pip demand a second hash line for the local wheel path.
    if bundle_mode_enabled; then
        # The signed lock IS the full closure -- Reachable, its dependencies and
        # the side installs -- every entry pinned and hashed. --no-deps because
        # the lock is complete (the builder proved it resolves); letting pip
        # re-resolve breaks on 3.14, where guarddog declares pygit2<1.19.
        if ! run_pip_with_retries "Installing from the bundle's signed lock" 1 \
            "$HOME/.reachable/venv/bin/python" -u -m pip install --no-deps --require-hashes \
                -r "$REACHABLE_AIRGAP_BUNDLE_ROOT/wheelhouse/requirements.lock"; then
            exit 1
        fi
        print_ok "Installed offline from the bundle (hash-pinned, manifest-bound)"
        configure_shell_path
        return
    fi
    if [[ "$CONSTRAINTS_MODE" == "hash" ]]; then
        if ! run_pip_with_retries "Installing hash-pinned dependencies" "$REACHABLE_PIP_ATTEMPTS" \
            "$HOME/.reachable/venv/bin/python" -u -m pip install --require-hashes -r constraints.txt; then
            exit 1
        fi
        print_ok "Dependency install verified from hash-pinned constraints"
        CONSTRAINTS_FLAG="--no-deps"
    fi

    # Install the main wheel.  --find-links lets pip resolve any remaining
    # dependencies from the vendor directory; --only-binary for each vendor
    # package prevents fallback to source builds when no compiler is present.
    VENDOR_FIND_LINKS_REMOTE=""
    if [[ "$HAS_VENDOR_REMOTE" == true ]]; then
        VENDOR_FIND_LINKS_REMOTE="--find-links vendor/"
    fi
    # Intentional word-splitting for optional pip flags.
    # shellcheck disable=SC2086,SC2046
    if ! run_pip_with_retries "Installing REACHABLE wheel" "$REACHABLE_PIP_ATTEMPTS" \
        "$HOME/.reachable/venv/bin/python" -u -m pip install \
        $VENDOR_FIND_LINKS_REMOTE \
        $(_vendor_only_binary_flags vendor/) \
        $CONSTRAINTS_FLAG "$WHEEL_FILE"; then
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
# Enclave steps for --bundle, before doctor. Each is an existing reachctl verb
# (AIRGAP-INSTALLER D15); this only sequences them. Without them doctor would
# try to download scanners and a vulnerability DB the enclave cannot reach.
bundle_enclave_setup() {
    local reachctl_bin="$1"
    local root="${REACHABLE_AIRGAP_BUNDLE_ROOT%/}"
    print_step "Staging the bundle's scanners"
    local tool archive
    for tool in syft grype gitleaks actionlint; do
        archive="$(ls "$root"/tools/"${tool}"_*_linux_*.tar.gz 2>/dev/null | head -1 || true)"
        if [[ -z "$archive" ]]; then
            print_error "The bundle carries no $tool archive under tools/ -- rebuild it"
            exit 1
        fi
        "$reachctl_bin" doctor prestage "$tool" "$archive" || exit 1
    done
    print_step "Importing the licence"
    "$reachctl_bin" token import "$AIRGAP_MIRROR_ROOT" || exit 1
    # Asked with REACHABLE_OFFLINE removed: a scan in a new shell has no
    # exported variable, so air-gap must hold from the installed licence alone.
    if ! env -u REACHABLE_OFFLINE "$HOME/.reachable/venv/bin/python" -I -c \
        'import sys; from reachable.core.airgap import air_gap_enabled; sys.exit(0 if air_gap_enabled() else 1)'; then
        print_error "The imported licence does not turn air-gap on (plan is not airgap)."
        print_error "A scan in a new shell would be allowed to reach the internet. Import an airgap-plan licence."
        exit 1
    fi
    print_step "Importing the signed intel snapshot"
    "$reachctl_bin" airgap feed import --from "$AIRGAP_MIRROR_ROOT" || exit 1
    print_step "Installing the venv scanners from the bundle (offline)"
    "$reachctl_bin" doctor --yes || exit 1
}

verify_installation() {
    print_header "Verification"

    VENV_REACHCTL="$HOME/.reachable/venv/bin/reachctl"
    mkdir -p "$REACHABLE_TMP_ROOT"
    if bundle_mode_enabled; then
        bundle_enclave_setup "$VENV_REACHCTL"
    fi

    echo ""
    echo -e "${BOLD}Doctor:${NC}"
    print_info "Installing required scanners and downloading the latest vulnerability database."
    print_info "Estimated time: 1-5 minutes on a normal connection; timeout: 10 minutes."
    if [[ "$REACHABLE_INSTALLER_AGENT_SETUP" == "1" ]]; then
        local doctor_log
        doctor_log="$(mktemp "$REACHABLE_TMP_ROOT/doctor.XXXXXX")"
        print_info "Doctor started"
        if "$VENV_REACHCTL" doctor --full > "$doctor_log" 2>&1; then
            if [[ -n "${INSTALL_LOG:-}" ]]; then
                {
                    echo ""
                    echo "=== doctor output ==="
                    cat "$doctor_log"
                } >> "$INSTALL_LOG"
            fi
            print_ok "Doctor passed"
        else
            if [[ -n "${INSTALL_LOG:-}" ]]; then
                {
                    echo ""
                    echo "=== doctor output ==="
                    cat "$doctor_log"
                } >> "$INSTALL_LOG"
            fi
            print_error "Verification failed: doctor did not complete successfully (see $INSTALL_LOG)"
            rm -f "$doctor_log"
            exit 1
        fi
        rm -f "$doctor_log"
    else
        if ! "$VENV_REACHCTL" doctor --full 2>&1 | sed 's/^/  /'; then
            print_error "Verification failed: reachctl doctor --full did not complete successfully"
            exit 1
        fi
    fi

    echo ""
    echo -e "${BOLD}Self-test:${NC}"
    print_info "Selftest started"
    if [[ "${REACHABLE_INSTALLER_VERBOSE_SELFTEST:-0}" == "1" ]]; then
        if "$VENV_REACHCTL" selftest 2>&1 | sed 's/^/  /'; then
            print_ok "Selftest passed"
        else
            print_warn "Selftest failed (non-fatal)"
        fi
    else
        selftest_log="$(mktemp "$REACHABLE_TMP_ROOT/selftest.XXXXXX")"
        if "$VENV_REACHCTL" selftest --quiet > "$selftest_log" 2>&1; then
            if [[ -n "${INSTALL_LOG:-}" ]]; then
                {
                    echo ""
                    echo "=== selftest output ==="
                    cat "$selftest_log"
                } >> "$INSTALL_LOG"
            fi
            print_ok "Selftest passed"
        else
            if [[ -n "${INSTALL_LOG:-}" ]]; then
                {
                    echo ""
                    echo "=== selftest output ==="
                    cat "$selftest_log"
                } >> "$INSTALL_LOG"
            fi
            print_warn "Selftest failed (non-fatal; see $INSTALL_LOG)"
        fi
        rm -f "$selftest_log"
    fi

    echo ""
    echo -e "${BOLD}Version:${NC}"
    if [[ "$REACHABLE_INSTALLER_AGENT_SETUP" == "1" ]]; then
        local version_line
        version_line="$("$VENV_REACHCTL" --version 2>/dev/null | sed -n '1p' || "$VENV_REACHCTL" version 2>/dev/null | sed -n '1p' || true)"
        print_info "$version_line"
    else
        "$VENV_REACHCTL" version 2>&1 | sed 's/^/  /'
    fi
}

# A directory the daemon may be pointed at: anything except the user's home
# directory and a filesystem root. Git is not required (see run_vibe_setup).
vibe_workspace_is_wireable() {
    local candidate
    candidate="$(cd -- "$1" 2>/dev/null && pwd -P)" || return 1
    [[ -n "$candidate" ]] || return 1
    case "$candidate" in
        /|"$(cd -- "$HOME" && pwd -P)") return 1 ;;
    esac
    [[ "$candidate" != "$(cd -- "$candidate/.." && pwd -P)" ]] || return 1
    return 0
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

# Always states the resolved surface and why it was resolved that way, so that
# "no daemon" is never something a user has to infer from its absence.
announce_vibe_surface() {
    if [[ "$ENABLE_VIBE_CODING" == true ]]; then
        print_step "Continuous surface: installing (reason: $VIBE_SURFACE_REASON)"
        print_info "Daemon, agent hooks, MCP server, and generated skills."
        if [[ "$VIBE_SURFACE_REASON" == "default" ]]; then
            print_info "Pass --no-vibe on CI runners and other ephemeral hosts to skip it."
        fi
    else
        print_step "Continuous surface: not installed (reason: $VIBE_SURFACE_REASON)"
        print_info "Scanner only: no daemon, no agent hooks, no MCP server, no skills."
        print_info "reachctl scan and reachctl remediate work; reachctl vibe * does not."
        print_info "To add the surface later, rerun the installer with --vibe."
        if [[ -n "$VIBE_WORKSPACE" ]]; then
            print_warn "--repo/--workspace '$VIBE_WORKSPACE' is unused: nothing is being wired."
        fi
    fi
}

run_vibe_setup() {
    announce_vibe_surface

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

    # A workspace does not need to be a git repository. Until 2026-10-26 a
    # plain directory was skipped here with "does not look like a git
    # repository" and the user told to retry from a repo root; a tester had to
    # `git init` to get wired. The daemon, the scanner and the default
    # `inplace` remediation mode handle non-git workspaces (reach-core
    # `baseline_config.current_branch_state`); only remediation's branch and
    # worktree modes need git, and they refuse by themselves. What the git
    # check was really guarding against is wiring the whole home directory
    # or the filesystem root as one workspace, so that is the check now.
    if ! vibe_workspace_is_wireable "$workspace"; then
        print_warn "Refusing to wire $workspace as a workspace: it is your home directory or a filesystem root"
        print_info "Retry from the project directory, or name it:"
        print_info "  curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --vibe --repo /path/to/project"
        return
    fi

    # `wire-workspace`, not `install`. Nothing is installed at this point --
    # the wheel and the daemon are already on the machine. This configures one
    # workspace. The old name made three separate callers each believe they
    # had to run it (here, the plugin's setup.sh, and its repair.sh), so a
    # workspace got wired up to three times and a failure in the last one
    # read as a failed install.
    #
    # reach-core keeps `install` as a hidden forwarding alias precisely so
    # THIS file can change first. Once this installer has propagated, that
    # alias gets deleted -- see reach_agent/cli.py.
    local -a vibe_cmd=("$reachctl_bin" vibe wire-workspace --repo "$workspace" --ci)
    local agent_name
    if ((${#VIBE_AGENTS[@]})); then
        for agent_name in "${VIBE_AGENTS[@]}"; do
            # wire-workspace expects the internal agent id (underscores, not hyphens)
            agent_name="${agent_name//-/_}"
            vibe_cmd+=(--agent "$agent_name")
        done
    fi
    if [[ "$VIBE_RUN_BASELINE" == true ]]; then
        vibe_cmd+=(--baseline-scan)
    fi

    if [[ "$REACHABLE_INSTALLER_AGENT_SETUP" == "1" ]]; then
        local vibe_log
        vibe_log="$(mktemp "$REACHABLE_TMP_ROOT/vibe-install.XXXXXX")"
        print_info "Workspace wiring started"
        if "${vibe_cmd[@]}" > "$vibe_log" 2>&1; then
            if [[ -n "${INSTALL_LOG:-}" ]]; then
                {
                    echo ""
                    echo "=== reach-vibe setup output ==="
                    cat "$vibe_log"
                } >> "$INSTALL_LOG"
            fi
            print_ok "Workspace wired"
            local ui_output
            ui_output="$("$reachctl_bin" vibe ui --repo "$workspace" --no-open 2>/dev/null || true)"
            VIBE_UI_URL="$(printf '%s\n' "$ui_output" | awk '/^https?:\/\// { url = $0 } END { print url }')"
            if [[ -n "$VIBE_UI_URL" ]]; then
                print_info "Dashboard: $VIBE_UI_URL"
            fi
        else
            if [[ -n "${INSTALL_LOG:-}" ]]; then
                {
                    echo ""
                    echo "=== reach-vibe setup output ==="
                    cat "$vibe_log"
                } >> "$INSTALL_LOG"
            fi
            print_warn "reach-vibe setup failed, but reachable itself is installed (see $INSTALL_LOG)"
            print_info "Retry later with: ${vibe_cmd[*]}"
        fi
        rm -f "$vibe_log"
    elif "${vibe_cmd[@]}"; then
        print_ok "reach-vibe installed for $workspace"
        local ui_output
        ui_output="$("$reachctl_bin" vibe ui --repo "$workspace" --no-open 2>/dev/null || true)"
        VIBE_UI_URL="$(printf '%s\n' "$ui_output" | awk '/^https?:\/\// { url = $0 } END { print url }')"
        if [[ -n "$VIBE_UI_URL" ]]; then
            print_info "Dashboard: $VIBE_UI_URL"
        fi
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
    local doctor_hint="reachctl doctor          # Add AI and GitHub tokens"
    local path_hint=""
    local summary_mode="${REACHABLE_INSTALLER_SUMMARY:-auto}"
    local compact_success=false
    local surface_line
    # State the surface explicitly in the upgrade command so an upgrade
    # reproduces this install instead of re-deciding it.
    if [[ "$ENABLE_VIBE_CODING" == true ]]; then
        upgrade_cmd="curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --update --vibe"
        surface_line="Surface: continuous — daemon, agent hooks, MCP server, skills (reason: $VIBE_SURFACE_REASON)"
    else
        upgrade_cmd="curl -fsSL ${PUBLIC_INSTALL_URL} | bash -s -- --update --no-vibe"
        surface_line="Surface: scanner only — no daemon, hooks, MCP server, or skills (reason: $VIBE_SURFACE_REASON)"
    fi
    case "$PATH_CONFIG_STATUS" in
        updated)
            path_hint="PATH configured in $PATH_CONFIG_TARGET — open a new shell to pick it up."
            ;;
        already-configured)
            path_hint="PATH already configured in $PATH_CONFIG_TARGET."
            ;;
        *)
            # Display text for the user, not a path this script expands.
            # shellcheck disable=SC2088
            path_hint="~/.reachable/venv/bin is available to the installer runtime."
            ;;
    esac
    if [[ "$summary_mode" == "compact" ]]; then
        compact_success=true
    elif [[ "$summary_mode" == "auto" ]]; then
        if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
            compact_success=true
        elif [[ "$ENABLE_VIBE_CODING" == true ]] && ((${#VIBE_AGENTS[@]} > 0)); then
            compact_success=true
        fi
    fi

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [[ "$compact_success" == true ]]; then
        if [[ "$UPDATE_MODE" == true ]]; then
            echo -e "${GREEN}  ✓ reachable upgraded successfully${NC}"
        elif [[ "$CLEAN_DATA" == true ]]; then
            echo -e "${GREEN}  ✓ reachable installed successfully (clean install)${NC}"
        else
            echo -e "${GREEN}  ✓ reachable installed successfully${NC}"
        fi
    elif [[ "$UPDATE_MODE" == true ]]; then
        echo -e "${GREEN}  ✓ REACHABLE upgraded successfully!${NC}"
    elif [[ "$CLEAN_DATA" == true ]]; then
        echo -e "${GREEN}  ✓ REACHABLE installed successfully! (clean install)${NC}"
    else
        echo -e "${GREEN}  ✓ REACHABLE installed successfully!${NC}"
    fi
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if [[ "$compact_success" == true ]]; then
        if [[ -n "$VIBE_UI_URL" ]]; then
            echo "  Dashboard: $VIBE_UI_URL"
        fi
        echo "  $surface_line"
        echo "  $path_hint"
        if [[ -n "${INSTALL_LOG:-}" ]]; then
            echo "  Install log: $INSTALL_LOG"
        fi
        if [[ "$ENABLE_VIBE_CODING" == true ]]; then
            echo "  Next: run reachable: doctor in the agent."
        else
            echo "  Next: run reachctl doctor, then reachctl scan /path/to/repo."
        fi
        echo ""
        return
    fi
    echo -e "  ${BOLD}Installed:${NC}"
    echo "    $surface_line"
    echo ""
    echo -e "  ${BOLD}Start Here:${NC}"
    if [[ "$ENABLE_VIBE_CODING" == true ]]; then
        if [[ -n "$VIBE_UI_URL" ]]; then
            echo "    Dashboard: $VIBE_UI_URL"
        fi
        echo "    reachctl vibe ui         # Open the local vibe dashboard"
        echo "    reachctl vibe status     # Show daemon and latest scan state"
    else
        echo "    reachctl scan /path      # Scan a repository"
    fi
    echo "    reachctl primer          # Full quick-start guide"
    echo "    $path_hint"
    echo ""
    echo -e "  ${BOLD}Enable AI:${NC}"
    echo "    Strongly recommended for better verdict quality and performance."
    echo "    $doctor_hint"
    echo "    OpenRouter: https://openrouter.ai/settings/keys"
    echo "    OpenAI:     https://platform.openai.com/api-keys"
    echo "    Anthropic:  https://console.anthropic.com/settings/keys"
    echo ""
    if [[ -n "$BACKUP_DIR" ]]; then
        echo -e "  ${BOLD}Backup:${NC} $BACKUP_DIR"
        echo ""
    fi
    echo -e "  ${BOLD}Maintain:${NC}"
    echo "    Installed:     v${VERSION}"
    echo "    List releases: $check_updates_cmd"
    echo "    Upgrade:       $upgrade_cmd"
    echo ""
    echo "  Docs: https://sthenosec.com  |  Support: info@sthenosec.com"
    echo "  © 2026 Sthenos Security, Inc. All rights reserved."
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
# `--uninstall`: the same removal as `reachable: uninstall --full`, for the
# user who installed with curl and wants out the same way. Everything runs
# through the installed reachctl (reach-core `reach_agent/cli.py uninstall
# --full`, AGENT-INTEGRATION-UNIFIED-INSTALL-DESIGN.md "Two Uninstalls"); this
# script only asks the question and names what is left when it cannot run.
run_uninstall() {
    local reachctl="$HOME/.reachable/venv/bin/reachctl"
    local workspace
    workspace="$(resolve_vibe_workspace)"
    print_header "REACHABLE Uninstall"
    if [[ ! -x "$reachctl" ]]; then
        print_error "No REACHABLE runtime at $HOME/.reachable/venv; the uninstall runs through it."
        if [[ -e "$HOME/.reachable" ]]; then
            print_info "$HOME/.reachable exists without a runtime (an install that did not finish)."
            print_info "Reinstall and run --uninstall again, or remove it by hand: rm -rf \"$HOME/.reachable\""
        else
            print_info "Nothing to uninstall."
        fi
        exit 1
    fi
    if [[ "$ASSUME_YES" != true ]]; then
        echo "  This removes REACHABLE from this machine: agent plugins, MCP server, daemon,"
        echo "  and $HOME/.reachable including scan history and credentials."
        # F-008: read from /dev/tty so the question works inside curl | bash.
        read -p "  Continue? [y/N] " -n 1 -r < /dev/tty
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Uninstall cancelled"
            exit 0
        fi
    fi
    "$reachctl" vibe uninstall --full --yes --workspace "$workspace"
}

main() {
    if [[ "$REACHABLE_INSTALLER_AGENT_SETUP" == "1" && "$UPDATE_MODE" == true ]]; then
        print_header "reachable upgrade v${VERSION}"
    elif [[ "$REACHABLE_INSTALLER_AGENT_SETUP" == "1" && "$CLEAN_DATA" == true ]]; then
        print_header "reachable clean install v${VERSION}"
    elif [[ "$REACHABLE_INSTALLER_AGENT_SETUP" == "1" ]]; then
        print_header "reachable installer v${VERSION}"
    elif [[ -n "$LOCAL_WHEEL" ]]; then
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

if [[ "${REACHABLE_INSTALLER_SOURCE_ONLY:-}" != "1" ]]; then
    if [[ "$UNINSTALL_MODE" == true ]]; then
        # No install log: it would be written into the directory being removed.
        run_uninstall
        exit 0
    fi
    setup_install_log

    if [[ "${REACHABLE_INSTALLER_VERIFY_ONLY:-}" == "1" ]]; then
        verify_installation
    else
        main "$@"
    fi
fi
