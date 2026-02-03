# Verifying REACHABLE Wheel Signatures

All wheels are cryptographically signed using [Sigstore cosign](https://github.com/sigstore/cosign)
with keyless OIDC via GitHub Actions. Signatures are logged to the
[Rekor transparency log](https://search.sigstore.dev/).

## Quick Verify

```bash
# Install cosign: https://docs.sigstore.dev/cosign/system_config/installation/
cosign verify-blob \
  --bundle reachable-*.whl.cosign.bundle \
  --certificate-identity-regexp="https://github.com/sthenos-security/reach-core/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  reachable-*.whl
```

Or use the included script:

```bash
./scripts/verify-wheel.sh reachable-*.whl
```

## What This Proves

- The wheel was built by the official Sthenos Security CI/CD pipeline
- It has not been tampered with since signing
- The signature is logged to a public transparency log
