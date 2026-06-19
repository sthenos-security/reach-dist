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
if [[ "$BACKUP_COUNT" != "1" ]]; then
    echo "expected exactly one reachable backup, found $BACKUP_COUNT" >&2
    find "$WORK_DIR" -maxdepth 2 -type d -print >&2
    exit 1
fi

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

echo "installer core install/upgrade test passed"
