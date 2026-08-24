#!/bin/bash
# Verify REACHABLE wheel signature (keyless cosign / Sigstore)
# Usage: ./verify-wheel.sh <wheel-file>
#
# Copyright © 2026 Sthenos Security. All rights reserved.

set -e

WHEEL="$1"

if [ -z "$WHEEL" ]; then
    echo "Usage: $0 <wheel-file>"
    echo "Example: $0 reachable-1.0.0b13-cp312-cp312-macosx_14_0_arm64.whl"
    exit 1
fi

if [ ! -f "$WHEEL" ]; then
    echo "Error: Wheel not found: $WHEEL"
    exit 1
fi

BUNDLE="${WHEEL}.cosign.bundle"

if [ ! -f "$BUNDLE" ]; then
    echo "Error: Signature bundle not found: $BUNDLE"
    echo "Download it from the same GitHub Release as the wheel."
    exit 1
fi

# Check cosign
if ! command -v cosign &> /dev/null; then
    echo "Error: cosign not installed"
    echo "Install: https://docs.sigstore.dev/cosign/system_config/installation/"
    echo ""
    echo "  brew install cosign        # macOS"
    echo "  go install github.com/sigstore/cosign/v2/cmd/cosign@latest  # Go"
    exit 1
fi

echo "Verifying: $WHEEL"
echo "Bundle:    $BUNDLE"
echo ""

# Read the signing identity from install.sh rather than restating it here.
#
# This script carried its own copy, and the copies had drifted: install.sh accepted
# ANY repo in the organisation, this one accepted any workflow on any REF of
# reach-core (including a branch build), and the design document specified a third
# value. Three scripts, three answers to "who is allowed to have signed this" -- and
# this is the one we hand customers to check our work, so it looked the most
# authoritative while being unanchored.
#
# install.sh is the single definition because it must be self-contained: it is
# downloaded standalone from the CDN and cannot source a sibling. This script lives
# beside it in the repo, so it can source it.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/install.sh" ]; then
    echo "Error: install.sh not found beside this script; cannot resolve the signing identity"
    exit 1
fi
# Read it in a CHILD shell, not by sourcing into this one. install.sh can call
# `exit` while being sourced, and an `exit` in the current shell cannot be caught by
# `|| true` -- it takes this script down with it, silently, before the verification
# runs. Found by tracing rather than by reading: the script exited 1 having printed
# only its banner, which looks indistinguishable from a quiet success if nobody
# checks the exit code.
COSIGN_IDENTITY_REGEXP="$(
    REACHABLE_INSTALLER_SOURCE_ONLY=1 bash -c \
        '. "$0" >/dev/null 2>&1; printf "%s" "${COSIGN_IDENTITY_REGEXP:-}"' \
        "$SCRIPT_DIR/install.sh"
)"
if [ -z "${COSIGN_IDENTITY_REGEXP:-}" ]; then
    # No fallback. Verifying against a guessed identity is worse than not verifying,
    # because it prints a success message.
    echo "Error: install.sh defines no COSIGN_IDENTITY_REGEXP; refusing to verify"
    echo "against an unknown signer."
    exit 1
fi

cosign verify-blob \
    --bundle "$BUNDLE" \
    --certificate-identity-regexp="$COSIGN_IDENTITY_REGEXP" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    "$WHEEL"

echo ""
# Precise about what was proven. The signature binds the artifact to one workflow in
# reach-core running on a release tag -- it does not, on its own, prove which commit
# that tag pointed at, because a tag can be moved. That is why reach-core carries a
# ruleset forbidding deletion and non-fast-forward on v* tags.
echo "✅ Signature verified — signed by the REACHABLE release workflow on a release tag"
