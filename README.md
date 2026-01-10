# REACHABLE Distribution

**Security Vulnerability Analysis with Reachability-Based Prioritization**

By [Sthenos Security](https://sthenosec.com)

---

## Security Guarantees

Every REACHABLE release includes:

| Security Measure | What It Proves | How to Verify |
|------------------|----------------|---------------|
| **Cosign Signature** | Built by Sthenos, not tampered | `cosign verify-blob` |
| **SHA256 Checksum** | File integrity | `sha256sum -c` |
| **Nuitka Compilation** | Source code protected | N/A (automatic) |
| **SBOM** | Full dependency list | Review `sbom.json` |
| **Rekor Log** | Immutable audit trail | search.sigstore.dev |

---

## Quick Start

```bash
# 1. Download wheel + signature + certificate
VERSION="4.5.9"
PLATFORM="cp311-cp311-macosx_14_0_arm64"  # Change for your platform
BASE="https://github.com/sthenos-security/reach-dist/releases/download/v${VERSION}"

curl -LO "${BASE}/reachable-${VERSION}-${PLATFORM}.whl"
curl -LO "${BASE}/reachable-${VERSION}-${PLATFORM}.whl.sig"
curl -LO "${BASE}/reachable-${VERSION}-${PLATFORM}.whl.crt"

# 2. Verify signature (recommended)
cosign verify-blob \
  --certificate "reachable-${VERSION}-${PLATFORM}.whl.crt" \
  --signature "reachable-${VERSION}-${PLATFORM}.whl.sig" \
  --certificate-identity-regexp "https://github.com/sthenos-security/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "reachable-${VERSION}-${PLATFORM}.whl"

# 3. Install
pip install "reachable-${VERSION}-${PLATFORM}.whl"

# 4. Install required external tools
mkdir -p ~/bin
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b ~/bin
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b ~/bin
export PATH="$HOME/bin:$PATH"

# 5. Verify installation
reachctl selftest

# 6. Scan your first repository
reachctl scan /path/to/your/repo
```

---

## Available Wheels

REACHABLE is compiled with **Nuitka** (Python → C → native binary) for:
- **Source code protection** - No readable Python source in the wheel
- **Performance** - Native execution speed
- **License enforcement** - C extension validates 30-day evaluation

### Current Release: v4.5.9

| Platform | Architecture | Wheel Filename |
|----------|--------------|----------------|
| **macOS 14+** | Apple Silicon (M1/M2/M3) | `reachable-4.5.9-cp311-cp311-macosx_14_0_arm64.whl` |
| **macOS 13+** | Intel (x86_64) | `reachable-4.5.9-cp311-cp311-macosx_13_0_x86_64.whl` |
| **Linux** | x86_64 | `reachable-4.5.9-cp311-cp311-manylinux_2_28_x86_64.whl` |
| **Linux** | ARM64 (Graviton) | `reachable-4.5.9-cp311-cp311-manylinux_2_28_aarch64.whl` |

Each release includes:
- `*.whl` - The compiled wheel
- `*.whl.sig` - Cosign signature
- `*.whl.crt` - Signing certificate
- `SHA256SUMS` - Checksums
- `sbom.json` - Software Bill of Materials
- `security-bulletin.md` - Self-scan results

### Which Wheel Do I Need?

```bash
# macOS
uname -m
# arm64 → macosx_14_0_arm64 (Apple Silicon)
# x86_64 → macosx_13_0_x86_64 (Intel)

# Linux
uname -m
# x86_64 → manylinux_2_28_x86_64
# aarch64 → manylinux_2_28_aarch64
```

---

## Signature Verification

### Why Verify?

The signature proves:
1. **Identity** - Built by `sthenos-security` GitHub org
2. **Integrity** - Wheel hasn't been modified since signing
3. **Auditability** - Logged in [Rekor](https://rekor.sigstore.dev) transparency log

### Install Cosign

```bash
# macOS
brew install cosign

# Linux (x86_64)
curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \
  -o /usr/local/bin/cosign && chmod +x /usr/local/bin/cosign
```

### Verify Command

```bash
cosign verify-blob \
  --certificate reachable-4.5.9-cp311-cp311-macosx_14_0_arm64.whl.crt \
  --signature reachable-4.5.9-cp311-cp311-macosx_14_0_arm64.whl.sig \
  --certificate-identity-regexp "https://github.com/sthenos-security/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  reachable-4.5.9-cp311-cp311-macosx_14_0_arm64.whl

# Expected: Verified OK
```

### What the Certificate Contains

```bash
openssl x509 -in *.whl.crt -text -noout | grep -A1 "Subject Alternative Name"
# URI:https://github.com/sthenos-security/reach-core/.github/workflows/release.yml@refs/tags/v4.5.9
```

This proves the wheel was built by that specific workflow at that specific tag.

---

## Checksum Verification

Quick integrity check (doesn't verify authenticity):

```bash
curl -LO https://github.com/sthenos-security/reach-dist/releases/download/v4.5.9/SHA256SUMS
sha256sum -c SHA256SUMS
```

---

## Installation

### Prerequisites

| Tool | Purpose | Required |
|------|---------|----------|
| Python 3.9+ | Runtime | Yes |
| syft | SBOM generation | Yes |
| grype | CVE scanning | Yes |
| libgit2 | GuardDog malware scanning | Optional |
| cosign | Signature verification | Optional |

### Step-by-Step

```bash
# 1. Create virtual environment
python3 -m venv reachable-env
source reachable-env/bin/activate

# 2. Verify and install wheel (see Quick Start above)
pip install reachable-4.5.9-*.whl

# 3. Install syft and grype
mkdir -p ~/bin
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b ~/bin
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b ~/bin
export PATH="$HOME/bin:$PATH"

# 4. (Optional) Install libgit2 for malware scanning
# macOS:
brew install libgit2
# Ubuntu:
sudo apt-get install libgit2-dev pkg-config

# 5. Verify
reachctl selftest
```

---

## Usage

```bash
# Scan a repository
reachctl scan /path/to/repo

# View dashboard
open ~/.reachable/scans/REPO/latest/dashboard/index.html

# CI/CD mode
reachctl scan . --quiet --fail-on critical --format sarif
```

---

## License

REACHABLE is proprietary software with a **30-day evaluation license**.

- **Evaluation:** Full functionality for 30 days from first run
- **Production:** Contact sales@sthenosec.com

---

## Support

| Channel | Contact |
|---------|---------|
| Documentation | https://docs.reachable.dev |
| Email | support@sthenosec.com |
| Enterprise | enterprise@sthenosec.com |
| Sales | sales@sthenosec.com |

---

## Files in This Repository

```
reach-dist/
├── README.md           # This file
├── VERIFICATION.md     # Detailed verification guide
├── CHANGELOG.md        # Version history
├── RELEASING.md        # Internal release process (maintainers)
└── releases/           # Release artifacts (or use GitHub Releases)
    └── v4.5.9/
        ├── reachable-4.5.9-cp311-cp311-macosx_14_0_arm64.whl
        ├── reachable-4.5.9-cp311-cp311-macosx_14_0_arm64.whl.sig
        ├── reachable-4.5.9-cp311-cp311-macosx_14_0_arm64.whl.crt
        ├── SHA256SUMS
        ├── sbom.json
        └── security-bulletin.md
```

---

© 2026 Sthenos Security. All Rights Reserved.
