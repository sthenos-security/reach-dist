#!/usr/bin/env bash
# Behaviour test for install.sh's openssl bootstrap (_bootstrap_openssl_verify).
#
# Until 2026-10-21 the bootstrap compared the key list's CLAIMED
# root_fingerprint to the pinned value and then verified the root signature
# with whatever root keys that same file listed. A key list naming an
# attacker's roots, with the published fingerprint string copied in and signed
# by those roots, passed. This runs the bootstrap's own Python, extracted from
# install.sh, against a genuine release and that forgery. openssl + python3
# only, like the bootstrap itself.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$ROOT_DIR/install.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

sed -n "/<<'BOOTSTRAP_PY'$/,/^BOOTSTRAP_PY$/p" "$INSTALLER" | sed '1d;$d' > "$WORK/bootstrap.py"
[[ -s "$WORK/bootstrap.py" ]] || fail "could not extract the bootstrap from install.sh"

# One release directory: key list signed by ROOT_KEY, claiming CLAIMED_FP;
# manifest signed by a fresh release key, binding the verifier + constraints.
make_release() {  # $1=dir $2=root_key.pem $3=mldsa_root_pubkey_b64 $4=claimed_fp
  local dir="$1" root="$2" mldsa="$3" claimed="$4"
  mkdir -p "$dir"
  openssl ecparam -name secp384r1 -genkey -noout -out "$dir/release.pem" 2>/dev/null
  echo "print('verifier')" > "$dir/verify_release_manifest.py"
  echo "cryptography==50.0.2 --hash=sha256:00" > "$dir/constraints.txt"
  python3 - "$dir" "$root" "$mldsa" "$claimed" <<'PY'
import base64, hashlib, json, pathlib, subprocess, sys
d, root, mldsa, claimed = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
def spki(pem):
    return base64.b64encode(subprocess.run(
        ["openssl", "ec", "-in", pem, "-pubout", "-outform", "DER"],
        capture_output=True, check=True).stdout).decode()
def entry(pub_b64, role):
    h = hashlib.sha384(base64.b64decode(pub_b64)).hexdigest()
    return {"key_id": h[:32], "pubkey": pub_b64, "role": role, "spki_sha384": h}
root_e = entry(spki(root), "root-ecdsa-p384")
keys = [root_e, entry(mldsa, "root-mldsa-87"),
        entry(spki(str(d / "release.pem")), "release-ecdsa-p384")]
(d / "key-list.json").write_text(json.dumps({
    "schema": "reachable.key-list.v1", "scope": "reachable-keylist", "version": 2,
    "issued_at": "2026-10-17T00:00:00Z", "root_fingerprint": claimed,
    "keys": keys, "rekor_keys": [], "revoked": []}, sort_keys=True))
subprocess.run(["openssl", "dgst", "-sha384", "-sign", root, "-out",
                str(d / f"key-list.{root_e['key_id']}.sig"), str(d / "key-list.json")], check=True)
arts = [{"name": n, "sha384": hashlib.sha384((d / n).read_bytes()).hexdigest()}
        for n in ("verify_release_manifest.py", "constraints.txt")]
(d / "reachable-signed-manifest.json").write_text(json.dumps({
    "schema": "reachable.release-manifest.v1", "scope": "reachable-release",
    "artifacts": arts}, sort_keys=True))
subprocess.run(["openssl", "dgst", "-sha384", "-sign", str(d / "release.pem"), "-out",
                str(d / "reachable-signed-manifest.json.p384.sig"),
                str(d / "reachable-signed-manifest.json")], check=True)
PY
}

fingerprint_of() {  # $1=root_key.pem $2=mldsa_b64 -> the fingerprint of that root set
  python3 - "$1" "$2" <<'PY'
import base64, hashlib, subprocess, sys
der = subprocess.run(["openssl", "ec", "-in", sys.argv[1], "-pubout", "-outform", "DER"],
                     capture_output=True, check=True).stdout
roots = sorted([hashlib.sha384(der).hexdigest(),
                hashlib.sha384(base64.b64decode(sys.argv[2])).hexdigest()])
print(base64.b64encode(hashlib.sha384("\n".join(roots).encode()).digest()).decode())
PY
}

run_bootstrap() { (cd "$1" && python3 "$WORK/bootstrap.py" "$2"); }

openssl ecparam -name secp384r1 -genkey -noout -out "$WORK/our-root.pem" 2>/dev/null
openssl ecparam -name secp384r1 -genkey -noout -out "$WORK/their-root.pem" 2>/dev/null
OUR_MLDSA="$(head -c 2592 /dev/urandom | base64 | tr -d '\n')"
THEIR_MLDSA="$(head -c 2592 /dev/urandom | base64 | tr -d '\n')"
PINNED="$(fingerprint_of "$WORK/our-root.pem" "$OUR_MLDSA")"

# Positive control: our roots, our fingerprint.
make_release "$WORK/genuine" "$WORK/our-root.pem" "$OUR_MLDSA" "$PINNED"
run_bootstrap "$WORK/genuine" "$PINNED" || fail "the genuine release was refused"

# The forgery: their roots, OUR published fingerprint copied into the claim.
make_release "$WORK/forged" "$WORK/their-root.pem" "$THEIR_MLDSA" "$PINNED"
if out="$(run_bootstrap "$WORK/forged" "$PINNED" 2>&1)"; then
  fail "a key list signed by foreign roots, claiming the pinned fingerprint, was ACCEPTED"
fi
grep -q "do not match the pinned fingerprint" <<<"$out" || fail "refused, but not for the fingerprint: $out"

echo "PASS: bootstrap recomputes the root fingerprint (genuine accepted, forgery refused)"
