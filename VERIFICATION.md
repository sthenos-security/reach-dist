# Verifying REACHABLE Releases

This document explains how to verify that a REACHABLE release is authentic and hasn't been tampered with.

---

## Why Verify?

When you download software, you want to be sure:

1. **Authenticity** - It was actually built by Sthenos Security
2. **Integrity** - It hasn't been modified since it was built
3. **Auditability** - There's a public record of the signature

REACHABLE uses [Sigstore](https://sigstore.dev) cosign for cryptographic signing—the same technology used by Kubernetes, npm, PyPI, and other major projects.

---

## Quick Verification

```bash
# Set version and platform
VERSION="1.0.0-beta4"
WHEEL_VERSION="1.0.0b4"
PYTHON="cp311"
PLATFORM="macosx_14_0_arm64"  # See platform options below

# Construct wheel name
WHEEL="reachable-${WHEEL_VERSION}-${PYTHON}-${PYTHON}-${PLATFORM}.whl"

# Download files
BASE_URL="https://github.com/sthenos-security/reach-dist/releases/download/v${VERSION}"
curl -LO "${BASE_URL}/${WHEEL}"
curl -LO "${BASE_URL}/${WHEEL}.sig"
curl -LO "${BASE_URL}/${WHEEL}.crt"

# Verify
cosign verify-blob \
  --certificate "${WHEEL}.crt" \
  --signature "${WHEEL}.sig" \
  --certificate-identity-regexp "https://github.com/sthenos-security/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "${WHEEL}"

# Expected output: Verified OK
```

---

## Supported Platforms

| Platform | Architecture | Platform Tag |
|----------|--------------|--------------|
| Linux | x86_64 | `manylinux_2_28_x86_64` |
| Linux | ARM64 | `manylinux_2_28_aarch64` |
| macOS | Apple Silicon | `macosx_14_0_arm64` |

> **Note:** macOS Intel wheels are not currently available.

### Python Version Tags

| Python | Tag |
|--------|-----|
| 3.10 | `cp310` |
| 3.11 | `cp311` |
| 3.12 | `cp312` |
| 3.13 | `cp313` |
| 3.14 | `cp314` |

---

## Install Cosign

### macOS

```bash
brew install cosign
```

### Linux (x86_64)

```bash
curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \
  -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign
```

### Linux (ARM64)

```bash
curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-arm64 \
  -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign
```

### Windows (PowerShell)

```powershell
Invoke-WebRequest -Uri https://github.com/sigstore/cosign/releases/latest/download/cosign-windows-amd64.exe -OutFile cosign.exe
```

---

## Understanding the Verification

### What You're Verifying

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `--certificate` | `*.whl.crt` | Public certificate with signer identity |
| `--signature` | `*.whl.sig` | Cryptographic signature of the wheel |
| `--certificate-identity-regexp` | `https://github.com/sthenos-security/.*` | Only accept signatures from sthenos-security GitHub org |
| `--certificate-oidc-issuer` | `https://token.actions.githubusercontent.com` | Only accept GitHub Actions OIDC tokens |

### What the Certificate Contains

The certificate proves **who** signed the artifact:

```bash
# View certificate details
openssl x509 -in reachable-*.whl.crt -text -noout | grep -A2 "Subject Alternative Name"
```

Output:
```
X509v3 Subject Alternative Name: critical
    URI:https://github.com/sthenos-security/reach-core/.github/workflows/release.yml@refs/tags/v1.0.0-beta4
```

This proves:
- **Repo:** `sthenos-security/reach-core`
- **Workflow:** `.github/workflows/release.yml`
- **Tag:** `v1.0.0-beta4`

### What the Signature Proves

| Claim | Proof |
|-------|-------|
| Built by Sthenos Security | Certificate identity matches `sthenos-security/*` |
| Built at specific version | Certificate contains `@refs/tags/v1.0.0-beta4` |
| Not tampered | Signature validates against wheel SHA256 |
| Publicly logged | Entry exists in Rekor transparency log |

---

## Checksum Verification (Alternative)

If you can't install cosign:

```bash
# Download checksums
curl -LO https://github.com/sthenos-security/reach-dist/releases/download/v1.0.0-beta4/checksums.sha256

# Verify
sha256sum -c checksums.sha256 --ignore-missing
# Expected: reachable-1.0.0b4-cp311-cp311-macosx_14_0_arm64.whl: OK
```

**⚠️ Checksums verify integrity but NOT authenticity.** An attacker could replace both the wheel and checksums. Use cosign for full verification.

---

## Rekor Transparency Log

Every signature is permanently logged in [Rekor](https://rekor.sigstore.dev), Sigstore's immutable transparency log.

### Search by Hash

```bash
# Get SHA256 of the wheel
DIGEST=$(sha256sum reachable-*.whl | cut -d' ' -f1)

# Search Rekor (requires rekor-cli)
rekor-cli search --sha "$DIGEST"

# View entry
rekor-cli get --uuid <UUID_FROM_SEARCH>
```

### Web Interface

Search at: **https://search.sigstore.dev**

Enter the SHA256 hash of the wheel to find the log entry.

---

## Offline Verification

For air-gapped environments:

```bash
cosign verify-blob \
  --certificate reachable-*.whl.crt \
  --signature reachable-*.whl.sig \
  --certificate-identity-regexp "https://github.com/sthenos-security/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --insecure-ignore-tlog \
  reachable-*.whl
```

**Note:** `--insecure-ignore-tlog` skips Rekor check. The signature is still cryptographically verified.

---

## Verification Script

Save as `verify-reachable.sh`:

```bash
#!/bin/bash
set -e

WHEEL="$1"
if [ -z "$WHEEL" ]; then
    echo "Usage: $0 <wheel-file>"
    exit 1
fi

SIG="${WHEEL}.sig"
CRT="${WHEEL}.crt"

# Check files exist
for f in "$WHEEL" "$SIG" "$CRT"; do
    [ -f "$f" ] || { echo "❌ Missing: $f"; exit 1; }
done

echo "🔍 Verifying: $WHEEL"

# Verify signature
if cosign verify-blob \
    --certificate "$CRT" \
    --signature "$SIG" \
    --certificate-identity-regexp "https://github.com/sthenos-security/.*" \
    --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
    "$WHEEL" 2>/dev/null; then
    echo "✅ Verified OK"
    echo "   Signed by: $(openssl x509 -in "$CRT" -noout -ext subjectAltName 2>/dev/null | grep URI | sed 's/.*URI://')"
else
    echo "❌ Verification FAILED"
    exit 1
fi
```

Usage:
```bash
chmod +x verify-reachable.sh
./verify-reachable.sh reachable-1.0.0b4-cp311-cp311-macosx_14_0_arm64.whl
```

---

## Troubleshooting

### "certificate identity not matched"

The certificate doesn't match `https://github.com/sthenos-security/.*`

Possible causes:
- Wheel was built by someone else
- Old release before cosign was set up
- **Wheel may be compromised**

### "signature verification failed"

The signature doesn't match the wheel content.

Possible causes:
- Corrupted download
- **Wheel may have been modified**

**Solution:** Re-download all files.

### "entry not found in transparency log"

Rekor doesn't have a record. Possible causes:
- Network issues
- Very recent signature (wait a few seconds)
- Signed locally without `--rekor-url` (rare)

---

## Questions?

Contact: adazzi@sthenosec.com
