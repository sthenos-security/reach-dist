#!/usr/bin/env bash
# install.sh keeps the verified vendor wheels in ~/.reachable/vendor-wheels,
# replacing any older set (reach-core design §16a rule 3, b286 #51): GuardDog
# setup repairs a stamped package that doesn't import from there. Runs the real
# keep_vendor_wheels from install.sh and checks it is called after both
# .vendor-stamp writers.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/keep-vendor.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"
mkdir -p "$HOME/.reachable/vendor-wheels" "$WORK/vendor"
touch "$HOME/.reachable/vendor-wheels/yara_python-4.5.3-cp313-cp313-old.whl"
touch "$WORK/vendor/yara_python-4.5.4-cp314-cp314-new.whl" "$WORK/vendor/psutil-7.2.2-cp36-abi3-new.whl"

REACHABLE_INSTALLER_SOURCE_ONLY=1 source "$HERE/install.sh"
keep_vendor_wheels "$WORK/vendor"

fail=0
check() { if eval "$2"; then echo "  PASS  $1"; else echo "  FAIL  $1"; fail=1; fi; }
kept="$(cd "$HOME/.reachable/vendor-wheels" && ls | sort | tr '\n' ' ')"
check "kept set is exactly the new wheels" '[[ "$kept" == "psutil-7.2.2-cp36-abi3-new.whl yara_python-4.5.4-cp314-cp314-new.whl " ]]'
writers="$(grep -c 'STAMP="$HOME/.reachable/venv/.vendor-stamp"' "$HERE/install.sh")"
calls="$(grep -cE '^\s+keep_vendor_wheels ' "$HERE/install.sh")"
check "every stamp writer keeps the wheels ($writers writers, $calls calls)" '[[ "$writers" -eq 2 && "$calls" -eq 2 ]]'
[[ $fail -eq 0 ]] && echo "keeps vendor wheels: PASS" || { echo "keeps vendor wheels: FAIL ($kept)"; exit 1; }
