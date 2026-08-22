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
curl -fsSL https://github.com/sigstore/cosign/releases/download/v3.1.3/cosign-linux-amd64 -o cosign
echo "4629c757b7618056f8ddd7e2625ae9fdd94c0372a65049520bc7d9df9efc7f71  cosign" | sha256sum -c -
sudo install -m 0755 cosign /usr/local/bin/cosign
```

**Linux (ARM64):**
```bash
curl -fsSL https://github.com/sigstore/cosign/releases/download/v3.1.3/cosign-linux-arm64 -o cosign
echo "c5d324e091826b0d7a78eb16fef316450b4eb9aaec045611c08ba06f5e73220a  cosign" | sha256sum -c -
sudo install -m 0755 cosign /usr/local/bin/cosign
```

> Do not fetch cosign from `releases/latest` without checking a digest. cosign
> is the tool that proves everything else is authentic; if it arrives over the
> same channel as the artifact it verifies, and unverified, an attacker able to
> intercept that channel can substitute a binary that approves anything.
> The digests above are for cosign **v3.1.3** and come from the Sigstore-signed
> `cosign_checksums.txt` published with that release. `install.sh` pins the same
> version and digests and aborts on mismatch.

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
