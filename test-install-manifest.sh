#!/usr/bin/env bash

set -euo pipefail

tmpdir="$(mktemp -d)"
script_head="$(mktemp)"
cleanup() {
    rm -rf "$tmpdir"
    rm -f "$script_head"
}
trap cleanup EXIT

cat >"$tmpdir/latest.json" <<'EOF'
{"ok":true,"version":"1.2.3b4"}
EOF

awk '/^VERSION=""/{exit} {print}' install.sh > "$script_head"

LATEST_MANIFEST_URL="file://$tmpdir/latest.json"
source "$script_head"

resolved="$(resolve_version)"
if [[ "$resolved" != "1.2.3b4" ]]; then
    echo "Expected 1.2.3b4, got: $resolved" >&2
    exit 1
fi

echo "OK: install.sh resolved manifest version $resolved"
