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

cosign verify-blob \
    --bundle "$BUNDLE" \
    --certificate-identity-regexp="https://github.com/sthenos-security/reach-core/.*" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    "$WHEEL"

echo ""
echo "✅ Signature verified — wheel was built by Sthenos Security CI/CD"
