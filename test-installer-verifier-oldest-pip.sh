#!/usr/bin/env bash
# The signature verifier installs with the oldest pip a supported CPython
# (3.11-3.14) ships, offline, from a wheelhouse -- exactly what an air-gap
# bundle install does, because without an index it cannot upgrade pip first.
#
# It did not: `pip install --require-hashes -c constraints.txt cryptography`
# needs pip 26+, which reads hashes from a constraints file. Older pip refuses
# the unpinned name, and the b236 air-gap install stopped there. The installer
# now cuts a requirements file with write_verifier_requirements; this test runs
# that function from install.sh itself, and checks the old form still fails so
# the test is known to catch it.
#
# Needs network once, to download the wheels it then installs offline.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
HEAD="$(mktemp)"
trap 'rm -rf "$WORK"; rm -f "$HEAD"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

OLDEST_PIP="24.0"   # ensurepip in CPython 3.11; 3.12-3.14 ship newer
PY="${PYTHON:-python3}"

awk '/^VERSION=""/{exit} {print}' "$ROOT_DIR/install.sh" > "$HEAD"
# shellcheck source=/dev/null
source "$HEAD"

# A hash-pinned constraints file for the verifier closure, as the release
# publishes it (hashes from the index, every platform).
"$PY" -m venv "$WORK/tool"
"$WORK/tool/bin/python" -m pip install -q --upgrade pip pip-tools >/dev/null
printf 'cryptography\n' > "$WORK/in.txt"
"$WORK/tool/bin/pip-compile" -q --generate-hashes --strip-extras \
  --output-file "$WORK/constraints.txt" "$WORK/in.txt"
{ printf 'annotated-types==0.7.0 \\\n    --hash=sha256:aaaa\n'; cat "$WORK/constraints.txt"; } > "$WORK/c2.txt"
mv "$WORK/c2.txt" "$WORK/constraints.txt"   # an unrelated entry the cut must drop

mkdir "$WORK/wheelhouse"
"$WORK/tool/bin/python" -m pip download -q --require-hashes \
  -r <(write_verifier_requirements "$WORK/constraints.txt") -d "$WORK/wheelhouse"

# 1. The cut keeps the verifier closure and nothing else.
write_verifier_requirements "$WORK/constraints.txt" > "$WORK/verifier.txt"
grep -q '^cryptography==' "$WORK/verifier.txt" || fail "cryptography missing from the cut"
grep -q '^annotated-types==' "$WORK/verifier.txt" && fail "the cut kept an unrelated package"

oldest_pip_venv() {
  rm -rf "$WORK/v"
  "$PY" -m venv "$WORK/v"
  "$WORK/v/bin/python" -m pip install -q "pip==$OLDEST_PIP" >/dev/null 2>&1
  [[ "$("$WORK/v/bin/python" -m pip --version | awk '{print $2}')" == "$OLDEST_PIP" ]] \
    || fail "could not set up pip $OLDEST_PIP"
}

# 2. The installer's form works offline with the oldest pip.
oldest_pip_venv
"$WORK/v/bin/python" -m pip install -q --no-index --find-links "$WORK/wheelhouse" \
  --require-hashes -r "$WORK/verifier.txt" \
  || fail "the verifier did not install with pip $OLDEST_PIP"
"$WORK/v/bin/python" -c 'import cryptography' || fail "cryptography not importable"

# 3. The form it replaced fails there, so this test can catch it.
oldest_pip_venv
if "$WORK/v/bin/python" -m pip install -q --no-index --find-links "$WORK/wheelhouse" \
     --require-hashes -c "$WORK/constraints.txt" cryptography >/dev/null 2>&1; then
  fail "the constraints form installed with pip $OLDEST_PIP; this test no longer proves anything"
fi

echo "OK: the signature verifier installs offline with pip $OLDEST_PIP"
