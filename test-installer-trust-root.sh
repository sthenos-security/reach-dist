#!/usr/bin/env bash
# Guards the release-manifest trust path in install.sh.
#
# cosign left the install path (docs/design/INSTALLER-ATTESTATION.md item 8).
# What authenticates a release now is:
#
#   pinned root fingerprint -> root-signed key-list.json -> dual-signed
#   reachable-signed-manifest.json -> sha384 of every bound artifact.
#
# These assertions fail if any link in that chain goes missing, if cosign
# creeps back into the install path, or if a failure path stops exiting.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$ROOT_DIR/install.sh"

fail() {
    echo "$1" >&2
    exit 1
}

# 1. cosign must not appear in install.sh at all. It stays in CI and in
#    verify-wheel.sh (the manual audit path); nothing a customer runs may
#    download, install, or consult it. A grep guard, not a behaviour test,
#    because the whole point is that the binary is never reached.
if grep -vE '^\s*#' "$INSTALLER" | grep -nE '\bcosign\b' | grep -q .; then
    echo "cosign is back in the install path:" >&2
    grep -nE '\bcosign\b' "$INSTALLER" >&2
    exit 1
fi

# 2. The pinned root fingerprint must be present and must be the published
#    value -- an installer with a different pin verifies a different root set.
grep -Fq "REACHABLE_ROOT_FINGERPRINT='kvQtc1UxbGgVbWqY9c2LJhmu1LPkiZrUToBo2rhf3/LWnMFn7UIZuI0HilEmrvIC'" \
    "$INSTALLER" \
    || fail "install.sh does not pin the published root fingerprint"

# 3. Every file the verification chain needs must be fetched. Missing-fetch
#    is how "verification" quietly becomes "trust on first use".
for f in key-list.json \
         reachable-signed-manifest.json \
         reachable-signed-manifest.json.p384.sig \
         reachable-signed-manifest.json.mldsa87.sig \
         verify_release_manifest.py \
         constraints.txt; do
    grep -Fq "$f" "$INSTALLER" \
        || fail "install.sh never fetches $f"
done

# 4. Root signatures are enumerated from the key list, not hardcoded -- a
#    rotated or added root must not strand the installer.
grep -Fq 'key-list." + k\["key_id"\] + ".sig\|key-list.*key_id.*\.sig' "$INSTALLER" \
    || grep -Fq 'key_id' "$INSTALLER" \
    || fail "root signature filenames are not derived from the key list"

# 5. The openssl bootstrap must run BEFORE the verifier script is trusted --
#    that is what authenticates the channel the verifier arrives through.
bootstrap_line=$(grep -n '_bootstrap_openssl_verify' "$INSTALLER" | grep -v '^\s*[0-9]*:.*()' | tail -1 | cut -d: -f1 || true)
verifier_line=$(grep -n 'verify_release_manifest.py "' "$INSTALLER" | tail -1 | cut -d: -f1 || true)
[[ -n "$bootstrap_line" ]] || fail "no _bootstrap_openssl_verify call found"
[[ -n "$verifier_line" ]] || fail "no verify_release_manifest.py invocation found"
(( bootstrap_line < verifier_line )) \
    || fail "openssl bootstrap (line $bootstrap_line) runs after the verifier ($verifier_line)"

# 6. The verifier runs with its own venv python (cryptography installed
#    hash-pinned), not the system python -- the ML-DSA half lives there --
#    and not the managed venv, which must not be touched before the release
#    is proven.
grep -Fq '"$VERIFIER_PY" verify_release_manifest.py' "$INSTALLER" \
    || fail "verifier is not run under the verifier venv python"
grep -Fq 'VERIFY_VENV="$(mktemp -d "$REACHABLE_TMP_ROOT/verify-venv.XXXXXX")"' "$INSTALLER" \
    || fail "no throwaway verifier venv"

# 6b. Every check finishes before the existing install is touched. Until
#     2026-11-02 the full verification (wheel and vendor digests, ML-DSA-87)
#     and the signed current-release statement ran after "Removing previous
#     installation", so a tampered upgrade was refused and left no install
#     (reach-core G24 run 41474869418). Order on the remote install path:
#     full verify < statement check < remove previous < create managed venv.
full_line=$(grep -n '"$VERIFIER_PY" verify_release_manifest.py' "$INSTALLER" | tail -1 | cut -d: -f1 || true)
statement_line=$(grep -n 'if ! verify_current_release_statement "$VERSION"; then' "$INSTALLER" | tail -1 | cut -d: -f1 || true)
remove_line=$(grep -n 'print_step "Removing previous installation"' "$INSTALLER" | tail -1 | cut -d: -f1 || true)
venv_line=$(grep -n '"$PY_BIN" -m venv "$HOME/.reachable/venv"' "$INSTALLER" | tail -1 | cut -d: -f1 || true)
[[ -n "$full_line" && -n "$statement_line" && -n "$remove_line" && -n "$venv_line" ]] \
    || fail "could not locate full verify ($full_line), statement ($statement_line), removal ($remove_line), venv ($venv_line)"
(( full_line < remove_line && statement_line < remove_line && remove_line < venv_line )) \
    || fail "the existing install is touched before the release is proven (verify $full_line, statement $statement_line, remove $remove_line, venv $venv_line)"

# 7. Fail-closed: a failed bootstrap or failed full verification must exit.
grep -A6 'Release verification FAILED' "$INSTALLER" | grep -Fq 'exit 1' \
    || fail "a failed release verification does not abort the install"

# 8. Artifacts passed to the verifier include the wheel and constraints.
grep -Fq 'VERIFY_ARTIFACTS=("$WHEEL_FILE" constraints.txt)' "$INSTALLER" \
    || fail "the wheel and constraints.txt are not both passed to the verifier"

echo "installer trust-root test passed"
