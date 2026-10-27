#!/usr/bin/env bash
# Behaviour test for install.sh's current-release statement check
# (verify_current_release_statement; reach-core INSTALLER-ATTESTATION §13.8).
#
# The version install.sh installs by default comes from latest.json, which
# nobody signs. Every release since b248 ships reachable-latest.json, signed
# by both release keys, naming itself current with an expiry. This runs the
# check's own Python, extracted from install.sh, against a release directory
# built with fresh P-384 and ML-DSA-87 keys: it passes a genuine, current
# statement and refuses one for another version, one that has expired, one
# for a different manifest, and one with a forged P-384 signature.
#
# Needs a python with `cryptography` >= 46 (ML-DSA). install.sh itself runs
# the check with ~/.reachable/venv/bin/python, where that is guaranteed; here
# PYTHON_BIN points at one (default: the product venv, else a scratch venv).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$ROOT_DIR/install.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

sed -n "/<<'LATEST_PY'$/,/^LATEST_PY$/p" "$INSTALLER" | sed '1d;$d' > "$WORK/latest_check.py"
[[ -s "$WORK/latest_check.py" ]] || fail "could not extract the current-release check from install.sh"
grep -q 'VERSION_FROM_LATEST_POINTER=true' "$INSTALLER" || fail "install.sh does not record that the version came from latest.json"
grep -q 'verify_current_release_statement "\$VERSION"' "$INSTALLER" || fail "install.sh does not run the check on a pointer-resolved version"

PYTHON_BIN="${PYTHON_BIN:-$HOME/.reachable/venv/bin/python}"
if ! "$PYTHON_BIN" -c 'from cryptography.hazmat.primitives.asymmetric import mldsa; mldsa.MLDSA87PrivateKey' >/dev/null 2>&1; then
  python3 -m venv "$WORK/venv" >/dev/null
  "$WORK/venv/bin/pip" install -q 'cryptography>=46' >/dev/null 2>&1 || fail "no python with ML-DSA cryptography and could not install one"
  PYTHON_BIN="$WORK/venv/bin/python"
fi

# A release directory: key list naming a P-384 and an ML-DSA-87 release key,
# a manifest, and a statement signed by both -- version/expiry/manifest digest
# as asked.
make_release() {  # $1=dir $2=stated_version $3=expires_at [$4=manifest_override]
  local dir="$1"
  mkdir -p "$dir"
  "$PYTHON_BIN" - "$dir" "$2" "$3" "${4:-}" <<'PY'
import base64, hashlib, json, pathlib, sys
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, mldsa
d, version, expires, manifest_override = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
p384 = ec.generate_private_key(ec.SECP384R1())
ml = mldsa.MLDSA87PrivateKey.generate()
def spki(pub):
    return base64.b64encode(pub.public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)).decode()
def entry(pub_b64, role):
    h = hashlib.sha384(base64.b64decode(pub_b64)).hexdigest()
    return {"key_id": h[:32], "pubkey": pub_b64, "role": role, "spki_sha384": h}
(d / "key-list.json").write_text(json.dumps({"schema": "reachable.key-list.v1", "keys": [
    entry(spki(p384.public_key()), "release-ecdsa-p384"), entry(spki(ml.public_key()), "release-mldsa-87")]}))
manifest = json.dumps({"schema": "reachable.release-manifest.v1", "version": "1.0.0b248", "artifacts": []})
(d / "reachable-signed-manifest.json").write_text(manifest)
bound = manifest_override.encode() if manifest_override else manifest.encode()
statement = json.dumps({"schema": "sthenos.reachable.latest/1", "product": "reachable", "version": version,
    "issued_at": "2026-10-27T00:00:00Z", "expires_at": expires,
    "manifest_sha384": hashlib.sha384(bound).hexdigest()}, sort_keys=True).encode()
(d / "reachable-latest.json").write_bytes(statement)
(d / "reachable-latest.json.p384.sig").write_bytes(p384.sign(statement, ec.ECDSA(hashes.SHA384())))
(d / "reachable-latest.json.mldsa87.sig").write_bytes(ml.sign(statement))
PY
}

run_check() { (cd "$1" && "$PYTHON_BIN" "$WORK/latest_check.py" "$2" 2>"$WORK/err"); }
FAR="2999-01-01T00:00:00Z"

# 1. Positive control: current, unexpired, this manifest.
make_release "$WORK/good" 1.0.0b248 "$FAR"
run_check "$WORK/good" 1.0.0b248 || fail "a genuine current statement was refused: $(cat "$WORK/err")"

# 2. The statement vouches for another version: the pointer sent us elsewhere.
make_release "$WORK/foreign" 1.0.0b230 "$FAR"
if run_check "$WORK/foreign" 1.0.0b248; then fail "a statement for another version was accepted"; fi
grep -q "names '1.0.0b230' as current, not '1.0.0b248'" "$WORK/err" || fail "foreign version not named: $(cat "$WORK/err")"

# 3. Expired: the release was never re-asserted.
make_release "$WORK/expired" 1.0.0b248 "2026-01-01T00:00:00Z"
if run_check "$WORK/expired" 1.0.0b248; then fail "an expired statement was accepted"; fi
grep -q "expired at 2026-01-01T00:00:00Z" "$WORK/err" || fail "expiry not named: $(cat "$WORK/err")"

# 4. A statement bound to a different manifest.
make_release "$WORK/othermanifest" 1.0.0b248 "$FAR" '{"other": true}'
if run_check "$WORK/othermanifest" 1.0.0b248; then fail "a statement for another manifest was accepted"; fi
grep -q "different manifest" "$WORK/err" || fail "manifest mismatch not named: $(cat "$WORK/err")"

# 5. Forged: the P-384 signature is from a key the key list does not name.
make_release "$WORK/forged" 1.0.0b248 "$FAR"
make_release "$WORK/forged-src" 1.0.0b248 "$FAR"
cp "$WORK/forged-src/reachable-latest.json.p384.sig" "$WORK/forged/reachable-latest.json.p384.sig"
if run_check "$WORK/forged" 1.0.0b248; then fail "a forged P-384 signature was accepted"; fi
grep -q "P-384 release signature does not verify" "$WORK/err" || fail "forgery not named: $(cat "$WORK/err")"

# 6. Forged ML-DSA half.
make_release "$WORK/forged-ml" 1.0.0b248 "$FAR"
cp "$WORK/forged-src/reachable-latest.json.mldsa87.sig" "$WORK/forged-ml/reachable-latest.json.mldsa87.sig"
if run_check "$WORK/forged-ml" 1.0.0b248; then fail "a forged ML-DSA signature was accepted"; fi
grep -q "ML-DSA-87 release signature does not verify" "$WORK/err" || fail "ML-DSA forgery not named: $(cat "$WORK/err")"

# 7. An explicit --version is the user's choice: the check is not run for it.
grep -q 'VERSION_FROM_LATEST_POINTER" == true' "$INSTALLER" || fail "the check is not gated on the pointer-resolved case"

echo "PASS: the installer accepts only a signed, unexpired statement that names this release"
