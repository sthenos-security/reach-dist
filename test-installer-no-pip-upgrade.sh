#!/usr/bin/env bash
# The installer never upgrades pip from the network. Every package it installs from an index is hash-pinned by the
# signed manifest's constraints.txt; `pip install --upgrade pip` was the one unpinned download, and it ran first,
# before the hash-pinned install, in the managed venv and in the signature-verifier venv (and in the --wheel path).
# The venv's own pip (ensurepip; CPython 3.11+ ships pip 22.3 or newer) installs `--require-hashes -r` requirements:
# the air-gap bundle path has always installed that way with no upgrade (test-installer-verifier-oldest-pip.sh).
#
# History: 2026-11-28 local install review (I-8).
#
# This test runs the real download_and_install from install.sh, remote path and --wheel path, against a fake HOME. The
# downloads, the openssl half of the verification and the vendor helpers are stand-ins; every interpreter the installer
# creates is a stub that records its arguments. It asserts no recorded call upgrades pip, and that the hash-pinned
# installs did run (so the assertion is over a run that reached them).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v python3 >/dev/null || fail "python3 is needed (the installer reads key-list.json with it)"

mkdir -p "$WORK/bin" "$WORK/vendor-src"
export WORK
export PIP_LOG="$WORK/pip-calls"
# Every venv python the installer creates: records its arguments, succeeds.
cat > "$WORK/bin/venv-python" <<'EOF'
#!/bin/sh
echo "$*" >> "$PIP_LOG"
exit 0
EOF
# PY_BIN: `-m venv DIR` makes a stub venv; anything else is the real python3 (key-list.json parsing).
cat > "$WORK/bin/pybin" <<EOF
#!/bin/sh
if [ "\$1" = "-m" ] && [ "\$2" = "venv" ]; then
  mkdir -p "\$3/bin" && cp "$WORK/bin/venv-python" "\$3/bin/python" && chmod +x "\$3/bin/python"
  exit 0
fi
exec python3 "\$@"
EOF
chmod +x "$WORK/bin/venv-python" "$WORK/bin/pybin"
echo "dummy" > "$WORK/vendor-src/yara_python-4.5.0-cp314-cp314-linux_x86_64.whl"
echo "dummy" > "$WORK/reachable-1.0.0b1-cp314-cp314-linux_x86_64.whl"

run_install() { # run_install <remote|wheel>
  rm -rf "${WORK:?}/home"; mkdir -p "$WORK/home"; : > "$PIP_LOG"
  HOME="$WORK/home" MODE="$1" "$BASH" -c '
    set -euo pipefail
    export REACHABLE_INSTALLER_SOURCE_ONLY=1
    installer="$1"; shift
    source "$installer"
    print_step()  { echo "STEP $1"; }
    print_ok()    { echo "OK $1"; }
    print_info()  { echo "  $1"; }
    print_warn()  { echo "WARN $1"; }
    print_error() { echo "ERROR $1"; }
    managed_reachable_version() { return 1; }
    download_dist_artifact() {
      case "$2" in
        key-list.json)   echo "{\"keys\":[{\"key_id\":\"r1\",\"role\":\"root\"}]}" > "$3" ;;
        constraints.txt) printf "cryptography==46.0.0 --hash=sha256:00\n" > "$3" ;;
        vendor-*)        tar czf "$3" -C "$WORK/vendor-src" . ;;
        *)               echo "dummy" > "$3" ;;
      esac
    }
    _bootstrap_openssl_verify() { return 0; }
    _retag_vendor_wheels() { :; }
    _vendor_package_names() { echo yara-python; }
    _vendor_only_binary_flags() { :; }
    _verify_vendor_wheels_import() { :; }
    keep_vendor_wheels() { :; }
    configure_shell_path() { :; }
    unset GITHUB_PATH
    PY_BIN="$WORK/bin/pybin"
    OS=linux PY_TAG=cp314 PLATFORM_TAG=linux_x86_64 PY_VERSION=3.14
    VERSION=1.0.0b1 WHEEL_VERSION=1.0.0b1 RELEASE_TAG=v1.0.0b1
    WHEEL_FILE=reachable-1.0.0b1-cp314-cp314-linux_x86_64.whl
    SKIP_RUNTIME_INSTALL=false VERSION_FROM_LATEST_POINTER=false INSTALL_CHANNEL=public
    REACHABLE_DIST_ROOT="" REACHABLE_DIST_BASE_URL=""
    if [[ "$MODE" == wheel ]]; then LOCAL_WHEEL="$WORK/$WHEEL_FILE"; else LOCAL_WHEEL=""; fi
    download_and_install
    echo "INSTALL RETURNED"
  ' _ "$ROOT_DIR/install.sh" 2>&1
}

# 1. Remote path: verifier venv and managed venv.
set +e; out="$(run_install remote)"; rc=$?; set -e
[[ "$rc" == 0 ]] || fail "remote install stand-in exited $rc. Output: $out"
grep -q 'INSTALL RETURNED' <<<"$out" || fail "remote install did not finish. Output: $out"
grep -q -- '--require-hashes -r verifier-requirements.txt' "$PIP_LOG" || fail "the verifier's hash-pinned install never ran: $(cat "$PIP_LOG")"
grep -q -- '--require-hashes -r constraints.txt' "$PIP_LOG" || fail "the hash-pinned dependency install never ran: $(cat "$PIP_LOG")"
if grep -E -- 'install .*--upgrade pip|install .*-U pip' "$PIP_LOG"; then
  fail "remote install upgraded pip from the network (unpinned)"
fi

# 2. --wheel path.
set +e; out="$(run_install wheel)"; rc=$?; set -e
[[ "$rc" == 0 ]] || fail "--wheel install stand-in exited $rc. Output: $out"
grep -q 'reachable-1.0.0b1-cp314-cp314-linux_x86_64.whl' "$PIP_LOG" || fail "the --wheel install never ran: $(cat "$PIP_LOG")"
if grep -E -- 'install .*--upgrade pip|install .*-U pip' "$PIP_LOG"; then
  fail "--wheel install upgraded pip from the network (unpinned)"
fi

echo "PASS: the installer never upgrades pip from the network"
