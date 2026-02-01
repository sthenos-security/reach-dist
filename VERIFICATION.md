# Verifying REACHABLE Releases

This document explains how to verify that a REACHABLE release is authentic and hasn't been tampered with.

---

## Why Verify?

When you download software, you want to be sure:

1. **Authenticity** — It was actually built by Sthenos Security
2. **Integrity** — It hasn't been modified since it was built
3. **Auditability** — There's a public record of the signature

REACHABLE uses [Sigstore](https://sigstore.dev) keyless cosign for cryptographic signing—the same technology used by Kubernetes, npm, PyPI, and other major projects. No long-lived signing keys exist; signatures are tied to GitHub Actions OIDC identity.

---

## Quick Verification

```bash
# Download the wheel and its bundle from the GitHub Release
WHEEL="reachable-1.0.0b13-cp312-cp312-macosx_14_0_arm64.whl"

cosign verify-blob \
    --bundle "${WHEEL}.cosign.bundle" \
    --certificate-identity-regexp="https://github.com/sthenos-security/reach-core/.*" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    "${WHEEL}"
```

On success:

```
✅ Signature verified — wheel was built by Sthenos Security CI/CD
```

---

## Step by Step

### 1. Install Cosign

**macOS:**

```bash
brew install cosign
```

**Linux (x86_64):**

```bash
curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \
    -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign
```

**Linux (ARM64):**

```bash
curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-arm64 \
    -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign
```

### 2. Download the Wheel and Bundle

Every wheel has a corresponding `.cosign.bundle` file in the same GitHub Release:

```bash
VERSION="1.0.0-beta13"
WHEEL_VERSION="1.0.0b13"
PYTHON="cp312"
PLATFORM="macosx_14_0_arm64"

WHEEL="reachable-${WHEEL_VERSION}-${PYTHON}-${PYTHON}-${PLATFORM}.whl"
BASE_URL="https://github.com/sthenos-security/reach-dist/releases/download/v${VERSION}"

curl -LO "${BASE_URL}/${WHEEL}"
curl -LO "${BASE_URL}/${WHEEL}.cosign.bundle"
```

### 3. Verify

```bash
cosign verify-blob \
    --bundle "${WHEEL}.cosign.bundle" \
    --certificate-identity-regexp="https://github.com/sthenos-security/reach-core/.*" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    "${WHEEL}"
```

---

## Supported Platforms

### Linux

| Architecture | Platform Tag |
|--------------|--------------|
| x86_64 (Intel/AMD) | `linux_x86_64` |
| ARM64 | `linux_aarch64` |

### macOS (Universal — Intel + Apple Silicon)

| Python | Platform Tag | Min macOS |
|--------|--------------|-----------|
| 3.10 | `macosx_10_9_universal2` | 10.9 |
| 3.11 | `macosx_10_9_universal2` | 10.9 |
| 3.12 | `macosx_10_13_universal2` | 10.13 |
| 3.13 | `macosx_10_13_universal2` | 10.13 |
| 3.14 | `macosx_10_15_universal2` | 10.15 |

### Python Version Tags

| Python | Tag |
|--------|-----|
| 3.10 | `cp310` |
| 3.11 | `cp311` |
| 3.12 | `cp312` |
| 3.13 | `cp313` |
| 3.14 | `cp314` |

---

## What the Verification Proves

| Claim | How |
|-------|-----|
| Built by Sthenos Security | Certificate identity matches `sthenos-security/reach-core` |
| Built at a specific git tag | Certificate contains `@refs/tags/v1.0.0-beta13` |
| Not tampered with | Signature validates against wheel content hash |
| Publicly logged | Entry recorded in Rekor transparency log |
| No long-lived keys | Keyless OIDC — ephemeral certificate issued per build |

---

## Checksum Verification (Alternative)

If you can't install cosign, verify using SHA256 checksums:

```bash
sha256sum -c checksums.sha256 --ignore-missing
```

**⚠️ Checksums verify integrity but NOT authenticity.** An attacker could replace both the wheel and checksums. Use cosign for full verification.

---

## Rekor Transparency Log

Every signature is permanently logged in [Rekor](https://rekor.sigstore.dev), Sigstore's immutable transparency log.

Search at: **https://search.sigstore.dev** — enter the SHA256 hash of the wheel to find the log entry.

---

## Offline Verification

For air-gapped environments, skip the Rekor check:

```bash
cosign verify-blob \
    --bundle "${WHEEL}.cosign.bundle" \
    --certificate-identity-regexp="https://github.com/sthenos-security/reach-core/.*" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    --insecure-ignore-tlog \
    "${WHEEL}"
```

**Note:** `--insecure-ignore-tlog` skips the transparency log check. The signature is still cryptographically verified.

---

## Troubleshooting

### "certificate identity not matched"

The certificate doesn't match `sthenos-security/reach-core`. The wheel may not have been built by Sthenos Security. **Do not install.**

### "signature verification failed"

The wheel content doesn't match the signature. Re-download both files. If it persists, **do not install.**

### "bundle not found"

Download the `.cosign.bundle` file from the same GitHub Release as the wheel.

---

## Questions?

Contact: adazzi@sthenosec.com

---

© 2026 Sthenos Security. All rights reserved.
