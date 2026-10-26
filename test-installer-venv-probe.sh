#!/usr/bin/env bash
# The --update venv probe must never delete a venv it cannot judge.
#
# 2026-10-19..26 (b231..b243): `_managed_venv_proves_itself` mapped the stamped
# package `ruamel-yaml-clib` to `import ruamel_yaml_clib` -- not a module, the
# wheel's top_level.txt is `_ruamel_yaml` -- so every healthy Linux venv failed
# the probe and `--update` deleted it. The installer then crashed on the
# python it had just removed. Two name maps existed; this test pins the ONE
# map both probes now read, against a real venv.
#
# Needs network once, to install ruamel.yaml, ruamel.yaml.clib and psutil.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
PY="${PYTHON:-python3}"

# The functions under test, from install.sh itself (sed-extracted, not retyped).
FUNCS="$WORK/funcs.sh"
for fn in _vendor_import_name _vendor_import_needs_dependency_tree _managed_venv_proves_itself; do
  sed -n "/^${fn}() {/,/^}/p" "$ROOT_DIR/install.sh" >> "$FUNCS"
  grep -q "^${fn}() {" "$FUNCS" || fail "could not extract ${fn} from install.sh"
done
cat >> "$FUNCS" <<'EOF'
print_info()  { echo "  $1"; }
print_warn()  { echo "  WARN $1"; }
print_error() { echo "  ERROR $1" >&2; }
EOF

export HOME="$WORK/home"
mkdir -p "$HOME/.reachable"
"$PY" -m venv "$HOME/.reachable/venv"
"$HOME/.reachable/venv/bin/python" -m pip install -q ruamel.yaml ruamel.yaml.clib psutil >/dev/null
printf 'psutil\nruamel-yaml-clib\n' > "$HOME/.reachable/venv/.vendor-stamp"

# 1. A healthy venv with the real stamp proves itself (the b243 failure).
if ! bash -c "source '$FUNCS'; _managed_venv_proves_itself"; then
  fail "a healthy venv stamped psutil + ruamel-yaml-clib did not pass the probe"
fi
echo "PASS healthy venv proves itself"

# 2. The map names the real module for every registered package.
for pair in "yara-python yara" "psutil psutil" "ruamel-yaml-clib _ruamel_yaml"; do
  set -- $pair
  got="$(bash -c "source '$FUNCS'; _vendor_import_name $1")"
  [[ "$got" == "$2" ]] || fail "_vendor_import_name $1 -> '$got', expected '$2'"
done
echo "PASS the map names the real modules"

# 3. ruamel is excluded from the standalone probe (needs the dependency tree),
#    psutil is not.
bash -c "source '$FUNCS'; _vendor_import_needs_dependency_tree ruamel-yaml-clib" \
  || fail "ruamel-yaml-clib must be marked as needing the dependency tree"
if bash -c "source '$FUNCS'; _vendor_import_needs_dependency_tree psutil"; then
  fail "psutil must be probed standalone"
fi
echo "PASS standalone exclusion is exactly ruamel"

# 4. An unregistered package aborts the INSTALLER (exit 1) -- never `return 1`,
#    which the caller reads as "delete and rebuild the venv".
printf 'psutil\nnonexistent-pkg\n' > "$HOME/.reachable/venv/.vendor-stamp"
set +e
out="$(bash -c "source '$FUNCS'; _managed_venv_proves_itself; echo 'reached-after-probe'" 2>&1)"
rc=$?
set -e
[[ $rc -eq 1 ]] || fail "unregistered package: expected exit 1, got $rc"
grep -q "no import name registered for vendor package 'nonexistent-pkg'" <<<"$out" \
  || fail "unregistered package did not name itself: $out"
grep -q 'reached-after-probe' <<<"$out" && fail "the probe returned instead of aborting"
echo "PASS unregistered package aborts loudly"

# 5. A genuinely broken venv still reads as unproven (the probe's real job).
rm -f "$HOME/.reachable/venv/lib/python"*/site-packages/_ruamel_yaml*.so
printf 'psutil\nruamel-yaml-clib\n' > "$HOME/.reachable/venv/.vendor-stamp"
if bash -c "source '$FUNCS'; _managed_venv_proves_itself" 2>/dev/null; then
  fail "a venv missing _ruamel_yaml.so passed the probe"
fi
echo "PASS a broken venv is unproven"
echo "OK"
