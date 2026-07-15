#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reachable-installer-core.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

assert_contains() {
    local file="$1"
    local needle="$2"
    if ! grep -Fq "$needle" "$file"; then
        echo "missing expected text in $file: $needle" >&2
        echo "--- $file ---" >&2
        sed -n '1,220p' "$file" >&2 || true
        exit 1
    fi
}

assert_not_contains() {
    local file="$1"
    local needle="$2"
    if grep -Fq "$needle" "$file"; then
        echo "unexpected text in $file: $needle" >&2
        echo "--- $file ---" >&2
        sed -n '1,220p' "$file" >&2 || true
        exit 1
    fi
}

assert_line_count() {
    local file="$1"
    local needle="$2"
    local expected="$3"
    local actual
    actual=$(grep -Fx "$needle" "$file" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$actual" != "$expected" ]]; then
        echo "expected $expected occurrence(s) in $file: $needle; found $actual" >&2
        echo "--- $file ---" >&2
        sed -n '1,220p' "$file" >&2 || true
        exit 1
    fi
}

HOME="$WORK_DIR/home"
mkdir -p "$HOME/.reachable/venv/bin"
export HOME
export REACHABLE_INSTALLER_SOURCE_ONLY=1

# shellcheck source=install.sh
source "$ROOT_DIR/install.sh"

configure_venv_pip_config
PIP_CONF="$HOME/.reachable/venv/pip.conf"
assert_contains "$PIP_CONF" "timeout = ${REACHABLE_PIP_TIMEOUT}"
assert_contains "$PIP_CONF" "retries = ${REACHABLE_PIP_RETRIES}"
assert_contains "$PIP_CONF" "disable-pip-version-check = true"
assert_contains "$PIP_CONF" "progress-bar = ${REACHABLE_PIP_PROGRESS_BAR}"

cat > "$HOME/.reachable/venv/bin/python" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == "-" ]]; then
    cat >/dev/null
    echo "1.0.0b112"
    exit 0
fi
if [[ "$1" == "-u" && "$2" == "-m" && "$3" == "pip" && "$4" == "uninstall" ]]; then
    echo "uninstalled $5"
    exit 0
fi
echo "unexpected python invocation: $*" >&2
exit 2
SH
chmod +x "$HOME/.reachable/venv/bin/python"

VERSION="1.0.0b113"
WHEEL_VERSION="1.0.0b113"
UPDATE_MODE=true
CLEAN_DATA=false
OUT="$WORK_DIR/upgrade-detect.out"
handle_existing_install >"$OUT"
assert_contains "$OUT" "Existing installation detected"
assert_contains "$OUT" "Installed version: 1.0.0b112"
assert_contains "$OUT" "Target version:    1.0.0b113"
BACKUP_COUNT="$(find "$HOME" -maxdepth 1 -type d -name '.reachable.backup.*' | wc -l | tr -d ' ')"
if [[ "$BACKUP_COUNT" != "0" ]]; then
    echo "expected no reachable backup during update, found $BACKUP_COUNT" >&2
    find "$WORK_DIR" -maxdepth 2 -type d -print >&2
    exit 1
fi
assert_contains "$OUT" "Update mode: preserving data in place; no backup copy created"

DOWNLOAD_SRC="$WORK_DIR/source.txt"
DOWNLOAD_OUT="$WORK_DIR/out.txt"
printf 'complete artifact\n' > "$DOWNLOAD_SRC"
download_with_retries "Downloading test artifact" "file://$DOWNLOAD_SRC" "$DOWNLOAD_OUT" >"$WORK_DIR/download.out"
assert_contains "$DOWNLOAD_OUT" "complete artifact"
assert_contains "$WORK_DIR/download.out" "downloaded "
assert_not_contains "$WORK_DIR/download.out" "###"
if find "$WORK_DIR" -name '*.part.*' | grep -q .; then
    echo "partial download artifact was left behind" >&2
    find "$WORK_DIR" -name '*.part.*' -print >&2
    exit 1
fi

SHELL="$WORK_DIR/bin/zsh"
mkdir -p "$WORK_DIR/bin"
touch "$SHELL"
export SHELL
RC_FILE="$HOME/.zshrc"
PATH_LINE='export PATH="$HOME/.reachable/venv/bin:$PATH"'

configure_shell_path
configure_shell_path
assert_line_count "$RC_FILE" "# Added by REACHABLE installer" "1"
assert_line_count "$RC_FILE" "$PATH_LINE" "1"

{
    echo "# existing user config"
    echo "# Added by REACHABLE installer"
    echo "$PATH_LINE"
    echo "# Added by REACHABLE installer"
    echo "$PATH_LINE"
    echo "export PATH=\"\$HOME/bin:\$PATH\""
} > "$RC_FILE"

configure_shell_path
assert_contains "$RC_FILE" "# existing user config"
assert_contains "$RC_FILE" 'export PATH="$HOME/bin:$PATH"'
assert_line_count "$RC_FILE" "# Added by REACHABLE installer" "1"
assert_line_count "$RC_FILE" "$PATH_LINE" "1"

if ! selector_looks_like_version "1.0.0b139"; then
    echo "expected beta version selector to be recognized as a version" >&2
    exit 1
fi
if selector_looks_like_version "agent-plugin-alpha-20260714-26e0ede"; then
    echo "expected alpha release tag selector to stay a tag, not a version" >&2
    exit 1
fi
if [[ "$(release_tag_for_version "1.0.0b139")" != "v1.0.0b139" ]]; then
    echo "release tag normalization failed" >&2
    exit 1
fi

resolve_version_from_release_tag() {
    local tag="$1"
    if [[ "$tag" != "agent-plugin-alpha-20260714-26e0ede" ]]; then
        echo "unexpected release tag lookup: $tag" >&2
        exit 1
    fi
    printf '1.0.0b139\n'
}

CUSTOM_VERSION="agent-plugin-alpha-20260714-26e0ede"
LOCAL_WHEEL=""
REACHABLE_DIST_ROOT=""
REACHABLE_DIST_BASE_URL=""
apply_version_selection
if [[ "$VERSION" != "1.0.0b139" ]]; then
    echo "expected resolved alpha version 1.0.0b139, got $VERSION" >&2
    exit 1
fi
if [[ "$WHEEL_VERSION" != "1.0.0b139" ]]; then
    echo "expected resolved alpha wheel version 1.0.0b139, got $WHEEL_VERSION" >&2
    exit 1
fi
if [[ "$RELEASE_TAG" != "agent-plugin-alpha-20260714-26e0ede" ]]; then
    echo "expected alpha release tag to stay exact, got $RELEASE_TAG" >&2
    exit 1
fi
EXPECTED_SOURCE="https://github.com/sthenos-security/reach-dist/releases/download/agent-plugin-alpha-20260714-26e0ede/reachable-1.0.0b139-cp314-cp314-macosx_11_0_universal2.whl"
ACTUAL_SOURCE="$(dist_artifact_source "reachable-1.0.0b139-cp314-cp314-macosx_11_0_universal2.whl")"
if [[ "$ACTUAL_SOURCE" != "$EXPECTED_SOURCE" ]]; then
    echo "unexpected alpha artifact source: $ACTUAL_SOURCE" >&2
    exit 1
fi

echo "installer core install/upgrade test passed"
