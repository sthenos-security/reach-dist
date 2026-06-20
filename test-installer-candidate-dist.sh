#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reachable-installer-candidate.XXXXXX")"
SCRIPT_HEAD="$(mktemp)"
trap 'rm -rf "$WORK_DIR"; rm -f "$SCRIPT_HEAD"' EXIT

assert_eq() {
    local expected="$1"
    local actual="$2"
    if [[ "$actual" != "$expected" ]]; then
        echo "expected: $expected" >&2
        echo "actual:   $actual" >&2
        exit 1
    fi
}

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

awk '/^VERSION=""/{exit} {print}' "$ROOT_DIR/install.sh" > "$SCRIPT_HEAD"

# shellcheck source=/dev/null
source "$SCRIPT_HEAD"

print_info() {
    printf 'info: %s\n' "$*"
}

CANDIDATE_ROOT="$WORK_DIR/candidate"
mkdir -p "$CANDIDATE_ROOT"
cat > "$CANDIDATE_ROOT/latest.json" <<'JSON'
{"ok": true, "version": "9.9.9a1"}
JSON
printf 'candidate artifact\n' > "$CANDIDATE_ROOT/artifact.txt"

REACHABLE_DIST_ROOT="$CANDIDATE_ROOT"
REACHABLE_DIST_BASE_URL=""
LATEST_MANIFEST_URL="file://$WORK_DIR/does-not-exist/latest.json"

resolved="$(resolve_version_from_candidate_dist)"
assert_eq "9.9.9a1" "$resolved"

download_dist_artifact "Downloading candidate artifact" artifact.txt "$WORK_DIR/copied.txt" > "$WORK_DIR/download.out"
assert_contains "$WORK_DIR/copied.txt" "candidate artifact"
assert_contains "$WORK_DIR/download.out" "Source: $CANDIDATE_ROOT/artifact.txt"
if find "$WORK_DIR" -name '*.part.*' | grep -q .; then
    echo "partial candidate artifact was left behind" >&2
    find "$WORK_DIR" -name '*.part.*' -print >&2
    exit 1
fi

REACHABLE_DIST_ROOT=""
REACHABLE_DIST_BASE_URL="https://example.test/reachable-candidate/"
source_url="$(dist_artifact_source checksums.sha256)"
assert_eq "https://example.test/reachable-candidate/checksums.sha256" "$source_url"

REACHABLE_DIST_BASE_URL=""
VERSION="1.2.3b4"
source_url="$(dist_artifact_source checksums.sha256)"
assert_eq "https://github.com/sthenos-security/reach-dist/releases/download/v1.2.3b4/checksums.sha256" "$source_url"

echo "installer candidate dist source test passed"
