#!/usr/bin/env bash
# Guards the constraints.txt authenticity gate in install.sh.
#
# constraints.txt is the authoritative dependency list: it is fed to
# `pip install --require-hashes -r constraints.txt`, so it decides which
# version of every dependency gets installed. It used to be fetched over the
# network and checked only with `grep -q -- --hash=`.
#
# That grep proves the file CONTAINS hashes. pip's --require-hashes then
# enforces those hashes against what it downloads. Both are internal-consistency
# checks, and neither authenticates the file. An attacker who rewrites it in
# transit adds a package whose hash matches their own real PyPI artifact, and
# pip installs it while reporting every hash as satisfied. Unlike
# checksums.sha256 -- whose forgery can only cause a false abort, because a
# cosign gate sits behind it -- nothing sat behind this one.
#
# The signature was published in every release the whole time and simply never
# downloaded.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$ROOT_DIR/install.sh"

fail() {
    echo "$1" >&2
    exit 1
}

# 1. The signature bundle must be fetched at all.
grep -Fq 'constraints.txt.cosign.bundle' "$INSTALLER" \
    || fail "install.sh never fetches constraints.txt.cosign.bundle"

# 2. It must be verified with cosign against our CI identity, not merely
#    downloaded. A bundle that is fetched and never checked is worse than none:
#    it looks like a control in a code review.
awk '
    /cosign verify-blob/ { in_block = 1; block = "" }
    in_block             { block = block $0 "\n" }
    in_block && /constraints\.txt/ && !/bundle/ { print block; in_block = 0 }
' "$INSTALLER" > /tmp/.constraints_verify_block.$$ || true

if [[ ! -s /tmp/.constraints_verify_block.$$ ]]; then
    rm -f /tmp/.constraints_verify_block.$$
    fail "constraints.txt is never passed to cosign verify-blob"
fi

for required in \
    '--bundle' \
    '--certificate-identity-regexp' \
    'https://github.com/sthenos-security/' \
    '--certificate-oidc-issuer' \
    'https://token.actions.githubusercontent.com'
do
    grep -Fq -- "$required" /tmp/.constraints_verify_block.$$ \
        || { rm -f /tmp/.constraints_verify_block.$$; fail "constraints verification is missing '$required' -- an unbound identity check verifies that SOMEBODY signed it"; }
done
rm -f /tmp/.constraints_verify_block.$$

# 3. Ordering: the verification must happen BEFORE the file is used. A gate
#    downstream of the thing it guards is not a gate.
# `|| true` on each capture is deliberate: under `set -euo pipefail` a grep that
# matches nothing aborts the whole script at this line, so the explicit
# diagnostic below never runs and the test fails with no message at all. Caught
# by mutation-testing this very file -- renaming the verified path made the test
# exit non-zero and print nothing, which is a failure nobody can act on.
verify_line=$(grep -n 'constraints.txt &>/dev/null' "$INSTALLER" | head -1 | cut -d: -f1 || true)
use_line=$(grep -n 'require-hashes' "$INSTALLER" | grep -v '^[[:space:]]*#' | tail -1 | cut -d: -f1 || true)
[[ -n "$verify_line" ]] \
    || fail "no cosign verification of constraints.txt found -- either it was removed, or the path it verifies was renamed so it no longer covers the file pip reads"
[[ -n "$use_line" ]] \
    || fail "could not locate the pip --require-hashes use of constraints.txt"
(( verify_line < use_line )) \
    || fail "constraints.txt is verified at line $verify_line but used at line $use_line -- the gate is downstream of what it guards"

# 4. Fail-closed: both the missing-bundle and the failed-verification paths must
#    exit non-zero. A `|| true` or a warning here reinstates the hole silently.
grep -A6 'Could not fetch constraints signature' "$INSTALLER" | grep -Fq 'exit 1' \
    || fail "a missing constraints signature does not abort the install"
grep -A6 'Constraints signature verification FAILED' "$INSTALLER" | grep -Fq 'exit 1' \
    || fail "a failed constraints signature does not abort the install"

# 5. The success message must not claim more than was checked. The old message
#    said "verified" after a grep for the literal string '--hash=', which is the
#    kind of wording that stops anyone from looking closer.
if grep -Fq 'Dependency constraints verified (hash-pinned)"' "$INSTALLER"; then
    fail "the success message still claims 'verified' for a shape check alone"
fi

echo "installer constraints signature test passed"
