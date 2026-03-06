# Verifying REACHABLE Releases

REACHABLE wheels are signed using [Sigstore](https://sigstore.dev) cosign with keyless OIDC via GitHub Actions. This provides cryptographic proof that each wheel was built by Sthenos Security and has not been tampered with.

---

## Quick Verification

```bash
cosign verify-blob \
  --certificate reachable-<version>-<platform>.whl.crt \
  --signature reachable-<version>-<platform>.whl.sig \
  --certificate-identity-regexp "https://github.com/sthenos-security/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  reachable-<version>-<platform>.whl
```

Expected output: `Verified OK`

---

## Install Cosign

**macOS:**
```bash
brew install cosign
```

**Linux (x86_64):**
```bash
curl -fsSL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \
  -o /usr/local/bin/cosign && chmod +x /usr/local/bin/cosign
```

**Linux (ARM64):**
```bash
curl -fsSL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-arm64 \
  -o /usr/local/bin/cosign && chmod +x /usr/local/bin/cosign
```

---

## Checksum Verification

Each release includes a `checksums.sha256` file:

```bash
sha256sum -c checksums.sha256 --ignore-missing
```

> Checksums verify integrity but not authenticity. Use cosign for full verification.

---

## Wheel Platform Tags

| Platform | Tag |
|----------|-----|
| Linux x86_64 | `linux_x86_64` |
| Linux ARM64 | `linux_aarch64` |
| macOS (Python 3.10–3.11) | `macosx_10_9_universal2` |
| macOS (Python 3.12–3.13) | `macosx_10_13_universal2` |
| macOS (Python 3.14) | `macosx_10_15_universal2` |

All macOS wheels are `universal2` — support both Intel and Apple Silicon.

---

## Offline / Air-Gapped Verification

```bash
cosign verify-blob \
  --certificate reachable-<version>-<platform>.whl.crt \
  --signature reachable-<version>-<platform>.whl.sig \
  --certificate-identity-regexp "https://github.com/sthenos-security/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --insecure-ignore-tlog \
  reachable-<version>-<platform>.whl
```

`--insecure-ignore-tlog` skips the Rekor transparency log check. The signature is still cryptographically verified.

---

## Questions?

Email: info@sthenosec.com

---

© 2026 Sthenos Security. All rights reserved.
