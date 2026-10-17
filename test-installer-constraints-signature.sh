#!/usr/bin/env bash
# Guards the constraints.txt authenticity gate in install.sh.
#
# constraints.txt is the authoritative dependency list: it is fed to
# `pip install --require-hashes -r constraints.txt`, so it decides which
# version of every dependency gets installed.
#
# It used to be authenticated by a cosign bundle of its own. Cosign left the
# install path (docs/design/INSTALLER-ATTESTATION.md item 8): constraints.txt
# is now a manifest-bound artifact — its sha384 is one of the digests inside
# reachable-signed-manifest.json, which carries both KMS signatures and is
# itself verified against the root-signed key list. These assertions pin that
# new mechanism in place, and fail if the cosign gate silently returns.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$ROOT_DIR/install.sh"

fail() {
    echo "$1" >&2
    exit 1
}

# 1. No constraints cosign bundle may be fetched or verified anymore.
grep -Fq 'constraints.txt.cosign.bundle' "$INSTALLER" \
    && fail "install.sh still fetches constraints.txt.cosign.bundle"

# 2. constraints.txt must be passed to the manifest verifier as a bound
#    artifact -- the check that replaced the cosign bundle.
grep -Fq 'VERIFY_ARTIFACTS=("$WHEEL_FILE" constraints.txt)' "$INSTALLER" \
    || fail "constraints.txt is not a manifest-verified artifact"

# 3. The verifier itself must be authenticated before it runs: its sha384 is
#    checked inside _bootstrap_openssl_verify against the manifest. Renaming
#    either side of that pair reopens the hole, so name both.
grep -Fq '"verify_release_manifest.py"' "$INSTALLER" \
    || grep -Fq 'verify_release_manifest.py' "$INSTALLER" \
    || fail "verify_release_manifest.py is not fetched or checked"

# 4. Ordering: the manifest verification must run BEFORE constraints.txt is
#    used by pip. A gate downstream of the thing it guards is not a gate.
verify_line=$(grep -n 'verify_release_manifest.py "${VERIFY_ARGS' "$INSTALLER" | head -1 | cut -d: -f1 || true)
use_line=$(grep -n -- '--require-hashes -r constraints.txt' "$INSTALLER" | tail -1 | cut -d: -f1 || true)
[[ -n "$verify_line" ]] \
    || fail "no manifest verification call found"
[[ -n "$use_line" ]] \
    || fail "could not locate the pip --require-hashes use of constraints.txt"
(( verify_line < use_line )) \
    || fail "constraints.txt is verified at line $verify_line but used at line $use_line -- the gate is downstream of what it guards"

# 5. Fail-closed: a failed verification must exit non-zero.
grep -A6 'Release verification FAILED' "$INSTALLER" | grep -Fq 'exit 1' \
    || fail "a failed release verification does not abort the install"

# 6. The cryptography install that carries the ML-DSA verifier is itself
#    hash-pinned via the manifest-authenticated constraints file.
grep -Fq -- '--require-hashes -c constraints.txt cryptography' "$INSTALLER" \
    || fail "cryptography is not installed hash-pinned from constraints.txt"

# 7. verify-wheel.sh -- the standalone customer audit script -- carries its own
#    literal identity now that install.sh no longer defines one.
if [ -f "$ROOT_DIR/verify-wheel.sh" ]; then
    grep -Fq 'COSIGN_IDENTITY_REGEXP=' "$ROOT_DIR/verify-wheel.sh" \
        || fail "verify-wheel.sh carries no signing identity"
fi

echo "installer constraints signature test passed"
