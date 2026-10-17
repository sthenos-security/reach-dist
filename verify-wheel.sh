#!/bin/bash
# Verify REACHABLE wheel signature (keyless cosign / Sigstore)
# Usage: ./verify-wheel.sh <wheel-file>
#
# Copyright © 2026 Sthenos Security, Inc. All rights reserved.

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

# The signing identity, as a literal. This script is the manual AUDIT path --
# install.sh no longer runs cosign at all (docs/design/INSTALLER-ATTESTATION.md
# item 8: the release manifest replaced it), so the constant cannot be read
# from it anymore. The canonical definition lives in
# reach-core: reach_agent/plugin_packages.py::COSIGN_IDENTITY_REGEXP, and
# tests/reach_agent/test_cosign_identity_is_pinned.py sweeps every copy.
COSIGN_IDENTITY_REGEXP='^https://github\.com/sthenos-security/reach-core/\.github/workflows/release[a-z0-9._-]*\.yml@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+(a|b|rc)?[0-9]*$'

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
