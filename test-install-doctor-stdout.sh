#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS="${RUNS:-3}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reachable-installer-doctor-stdout.XXXXXX")"
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

for run in $(seq 1 "$RUNS"); do
    HOME_DIR="$WORK_DIR/home-$run"
    BIN_DIR="$HOME_DIR/.reachable/venv/bin"
    mkdir -p "$BIN_DIR"

    FAKE_LOG="$WORK_DIR/reachctl-$run.log"
    cat > "$BIN_DIR/reachctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${REACHABLE_FAKE_REACHCTL_LOG:?}"
case "$1" in
    doctor)
        if [[ "${2:-}" != "--full" ]]; then
            echo "unexpected doctor args: $*" >&2
            exit 2
        fi
        echo "REACHABLE SYSTEM CHECK"
        echo "[2/6] Required Tools"
        echo "   Installing grype..."
        echo "   grype installed"
        echo "   Downloading latest vulnerability database (first install; estimated 1-5 minutes, timeout 10 minutes)..."
        echo "   latest vulnerability database downloaded"
        ;;
    selftest)
        if [[ "${2:-}" != "--quiet" ]]; then
            echo "unexpected selftest args: $*" >&2
            exit 2
        fi
        echo "selftest ok"
        ;;
    version)
        echo "REACHABLE test-version"
        ;;
    *)
        echo "unexpected command: $*" >&2
        exit 2
        ;;
esac
SH
    chmod +x "$BIN_DIR/reachctl"

    STDOUT_LOG="$WORK_DIR/stdout-$run.log"
    STDERR_LOG="$WORK_DIR/stderr-$run.log"
    HOME="$HOME_DIR" \
        REACHABLE_FAKE_REACHCTL_LOG="$FAKE_LOG" \
        REACHABLE_INSTALLER_VERIFY_ONLY=1 \
        "$ROOT_DIR/install.sh" >"$STDOUT_LOG" 2>"$STDERR_LOG"

    assert_contains "$FAKE_LOG" "doctor --full"
    assert_contains "$STDOUT_LOG" "Doctor:"
    assert_contains "$STDOUT_LOG" "Install log: $HOME_DIR/.reachable/logs/install/install-"
    assert_contains "$STDOUT_LOG" "Installing required scanners and downloading the latest vulnerability database."
    assert_contains "$STDOUT_LOG" "Estimated time: 1-5 minutes on a normal connection; timeout: 10 minutes."
    assert_contains "$STDOUT_LOG" "REACHABLE SYSTEM CHECK"
    assert_contains "$STDOUT_LOG" "Downloading latest vulnerability database (first install; estimated 1-5 minutes, timeout 10 minutes)..."
    assert_contains "$STDOUT_LOG" "Self-test:"
    assert_contains "$STDOUT_LOG" "Selftest started"
    assert_contains "$STDOUT_LOG" "Selftest passed"
    assert_not_contains "$STDOUT_LOG" "selftest ok"
    assert_contains "$STDOUT_LOG" "Version:"
    assert_contains "$STDOUT_LOG" "REACHABLE test-version"
    assert_not_contains "$STDOUT_LOG" "reachable-doctor"

    if [[ -s "$STDERR_LOG" ]]; then
        echo "installer verification wrote unexpected stderr on run $run" >&2
        sed -n '1,220p' "$STDERR_LOG" >&2
        exit 1
    fi

    LOG_LIST="$WORK_DIR/install-logs-$run.txt"
    find "$HOME_DIR/.reachable/logs/install" -type f -name 'install-*.log' | sort > "$LOG_LIST"
    LOG_COUNT="$(wc -l < "$LOG_LIST" | tr -d ' ')"
    if [[ "$LOG_COUNT" != "1" ]]; then
        echo "expected exactly one install log on run $run, found $LOG_COUNT" >&2
        find "$HOME_DIR/.reachable" -maxdepth 4 -type f -print >&2 || true
        exit 1
    fi
    INSTALL_LOG="$(sed -n '1p' "$LOG_LIST")"
    assert_contains "$INSTALL_LOG" "Doctor:"
    assert_contains "$INSTALL_LOG" "Installing required scanners and downloading the latest vulnerability database."
    assert_contains "$INSTALL_LOG" "Estimated time: 1-5 minutes on a normal connection; timeout: 10 minutes."
    assert_contains "$INSTALL_LOG" "REACHABLE SYSTEM CHECK"
    assert_contains "$INSTALL_LOG" "Downloading latest vulnerability database (first install; estimated 1-5 minutes, timeout 10 minutes)..."
    assert_contains "$INSTALL_LOG" "Self-test:"
    assert_contains "$INSTALL_LOG" "=== selftest output ==="
    assert_contains "$INSTALL_LOG" "selftest ok"
    assert_contains "$INSTALL_LOG" "Version:"
done

echo "installer doctor stdout test passed ($RUNS runs)"
