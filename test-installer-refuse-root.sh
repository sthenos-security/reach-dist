#!/usr/bin/env bash
# The installer refuses to run as root unless --allow-root is given, and refuses before any persistent change
# (installer test plan TP-D3: "root refused by default with an `--allow-root` override ... Every refusal happens before
# any persistent change").
#
# History: 2026-11-28 local install review (I-9a): `sudo ./install.sh` ran to the end and left root-owned files in the
# user's ~/.reachable that the user's own later installs and the daemon could not update. A container that runs as
# root (release-acceptance Linux cells, the air-gap offline proof) passes --allow-root.
#
# This test runs the real top-level guard and the real refusal from install.sh, with a stub `id` and a fake HOME; the
# install steps themselves are stand-ins that record that they were reached.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

mkdir -p "$WORK/bin"
cat > "$WORK/bin/id" <<'EOF'
#!/bin/sh
if [ "$1" = "-u" ]; then echo "$STUB_UID"; exit 0; fi
echo "stub id: unexpected arguments: $*" >&2
exit 3
EOF
chmod +x "$WORK/bin/id"

# The top-level guard of install.sh: everything from the SOURCE_ONLY check to the end of the file.
GUARD="$WORK/guard.sh"
awk '/^if \[\[ "\$\{REACHABLE_INSTALLER_SOURCE_ONLY:-\}" != "1" \]\]; then/{p=1} p' "$ROOT_DIR/install.sh" > "$GUARD"
grep -q 'setup_install_log' "$GUARD" || fail "could not extract the top-level guard from install.sh"

run_case() { # run_case <uid> <installer args...>  -> prints output, returns the guard's exit code
  local uid="$1"; shift
  HOME="$WORK/home" STUB_UID="$uid" PATH="$WORK/bin:$PATH" "$BASH" -c '
    set -euo pipefail
    export REACHABLE_INSTALLER_SOURCE_ONLY=1
    installer="$1"; shift
    source "$installer" "$@"
    print_header() { :; }
    setup_install_log() { mkdir -p "$HOME/.reachable/logs"; echo "REACHED setup_install_log"; }
    main()              { echo "REACHED main"; }
    run_uninstall()     { echo "REACHED run_uninstall"; }
    verify_installation() { echo "REACHED verify_installation"; }
    unset REACHABLE_INSTALLER_SOURCE_ONLY
    source "$0"
  ' "$GUARD" "$ROOT_DIR/install.sh" "$@" 2>&1
}

# 1. Root without the override: refused, exit 2, named reason and the override, nothing written, no step reached.
rm -rf "${WORK:?}/home"; mkdir -p "$WORK/home"
set +e; out="$(run_case 0)"; rc=$?; set -e
[[ "$rc" == 2 ]] || fail "root without --allow-root: expected exit 2, got $rc. Output: $out"
grep -q 'Refusing to run as root' <<<"$out" || fail "root refusal does not say why. Output: $out"
grep -q -- '--allow-root' <<<"$out" || fail "root refusal does not name the --allow-root override. Output: $out"
grep -q 'REACHED' <<<"$out" && fail "root refusal still reached an install step. Output: $out"
[[ ! -e "$WORK/home/.reachable" ]] || fail "root refusal left $WORK/home/.reachable behind"

# 2. Root uninstall without the override: refused the same way (it would run root's reachctl over the user's data).
set +e; out="$(run_case 0 --uninstall)"; rc=$?; set -e
[[ "$rc" == 2 ]] || fail "root --uninstall without --allow-root: expected exit 2, got $rc. Output: $out"
grep -q 'REACHED' <<<"$out" && fail "root --uninstall refusal reached a step. Output: $out"

# 3. Root with --allow-root: goes on, says it is installing for root.
set +e; out="$(run_case 0 --allow-root)"; rc=$?; set -e
[[ "$rc" == 0 ]] || fail "root with --allow-root: expected exit 0, got $rc. Output: $out"
grep -q 'REACHED main' <<<"$out" || fail "root with --allow-root did not reach main. Output: $out"
grep -q 'allow-root' <<<"$out" || fail "root with --allow-root does not say it runs as root. Output: $out"

# 4. A normal user: no refusal, no root notice.
rm -rf "${WORK:?}/home"; mkdir -p "$WORK/home"
set +e; out="$(run_case 501)"; rc=$?; set -e
[[ "$rc" == 0 ]] || fail "uid 501: expected exit 0, got $rc. Output: $out"
grep -q 'REACHED main' <<<"$out" || fail "uid 501 did not reach main. Output: $out"
grep -qi 'root' <<<"$out" && fail "uid 501 got a root message. Output: $out"

# 5. --help documents the override.
help="$(HOME="$WORK/home" "$BASH" "$ROOT_DIR/install.sh" --help)"
grep -q -- '--allow-root' <<<"$help" || fail "--help does not document --allow-root"

echo "PASS: installer refuses root unless --allow-root, before any change"
