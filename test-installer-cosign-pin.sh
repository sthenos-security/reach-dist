#!/usr/bin/env bash
# Guards the pinned-cosign path in install.sh: the signature verifier must
# itself be version-pinned and digest-verified, and must fail closed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reachable-installer-cosign.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

assert_eq() {
    local expected="$1"
    local actual="$2"
    if [[ "$actual" != "$expected" ]]; then
        echo "expected: $expected" >&2
        echo "actual:   $actual" >&2
        exit 1
    fi
}

# The installer must never fetch cosign from an unpinned "latest" URL.
if grep -Fq "sigstore/cosign/releases/latest" "$ROOT_DIR/install.sh"; then
    echo "install.sh still downloads cosign from releases/latest (unpinned)" >&2
    exit 1
fi

HOME="$WORK_DIR/home"
mkdir -p "$HOME"
export HOME
export REACHABLE_INSTALLER_SOURCE_ONLY=1

# shellcheck source=install.sh
source "$ROOT_DIR/install.sh"

# Every platform we auto-install for has a pinned digest.
for target in linux-amd64 linux-arm64 darwin-amd64 darwin-arm64; do
    os="${target%-*}"
    arch="${target#*-}"
    digest="$(cosign_pinned_sha256 "$os" "$arch")"
    if [[ ! "$digest" =~ ^[0-9a-f]{64}$ ]]; then
        echo "no valid pinned digest for $target: '$digest'" >&2
        exit 1
    fi
done

# Unknown platforms fail rather than defaulting to something.
if cosign_pinned_sha256 "plan9" "sparc" >/dev/null 2>&1; then
    echo "cosign_pinned_sha256 returned a digest for an unsupported platform" >&2
    exit 1
fi

ARCH_SUFFIX="$(uname -m)"
case "$ARCH_SUFFIX" in
    x86_64|amd64)  ARCH_SUFFIX="amd64" ;;
    aarch64|arm64) ARCH_SUFFIX="arm64" ;;
esac
OS_UNDER_TEST="linux"
PINNED_DIGEST="$(cosign_pinned_sha256 "$OS_UNDER_TEST" "$ARCH_SUFFIX")"

# Stub the download so no network is needed. CONTENT decides what "cosign" is.
CONTENT="tampered"
download_with_retries() {
    local url="$2"
    local output="$3"
    case "$url" in
        *"/releases/download/${COSIGN_PINNED_VERSION}/cosign-${OS_UNDER_TEST}-${ARCH_SUFFIX}") ;;
        *)
            echo "unexpected cosign URL: $url" >&2
            return 1
            ;;
    esac
    printf '%s' "$CONTENT" > "$output"
}

# 1. A binary whose digest does not match the pin must abort, and must not be
#    installed anyway.
OUT="$WORK_DIR/mismatch.out"
set +e
install_pinned_cosign "$OS_UNDER_TEST" >"$OUT" 2>&1
STATUS=$?
set -e
assert_eq 1 "$STATUS"
if ! grep -Fq "COSIGN BINARY DIGEST MISMATCH" "$OUT"; then
    echo "digest mismatch did not produce the named error" >&2
    cat "$OUT" >&2
    exit 1
fi
if [[ -e "$HOME/.reachable/tools/bin/cosign" ]]; then
    echo "cosign was installed despite a digest mismatch" >&2
    exit 1
fi

# 2. A binary matching the pinned digest installs and lands on PATH.
CONTENT="$(printf 'x')"
# Recompute the pin so the happy path exercises the real comparison.
if command -v sha256sum &>/dev/null; then
    CONTENT_DIGEST="$(printf '%s' "$CONTENT" | sha256sum | awk '{print $1}')"
else
    CONTENT_DIGEST="$(printf '%s' "$CONTENT" | shasum -a 256 | awk '{print $1}')"
fi
cosign_pinned_sha256() { echo "$CONTENT_DIGEST"; }

OUT="$WORK_DIR/match.out"
install_pinned_cosign "$OS_UNDER_TEST" >"$OUT" 2>&1
if [[ ! -x "$HOME/.reachable/tools/bin/cosign" ]]; then
    echo "cosign was not installed on the matching-digest path" >&2
    cat "$OUT" >&2
    exit 1
fi
case ":$PATH:" in
    *":$HOME/.reachable/tools/bin:"*) ;;
    *)
        echo "tools/bin was not prepended to PATH" >&2
        exit 1
        ;;
esac
if [[ -z "$PINNED_DIGEST" ]]; then
    echo "expected a real pinned digest for ${OS_UNDER_TEST}-${ARCH_SUFFIX}" >&2
    exit 1
fi

echo "installer cosign pinning test passed"
