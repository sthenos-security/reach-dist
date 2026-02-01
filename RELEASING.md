# Releasing REACHABLE

Internal documentation for the release process.

---

## Release Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   reach-core    │────►│  GitHub Actions │────►│   reach-dist    │
│   (source)      │     │   (CI/CD)       │     │   (distribute)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        │                       ▼                       │
        │               ┌───────────────┐               │
        │               │ Build Matrix  │               │
        │               │ • 3 platforms │               │
        │               │ • 5 Python    │               │
        │               │ • 15 wheels   │               │
        │               └───────────────┘               │
        │                       │                       │
        │                       ▼                       │
        │               ┌───────────────┐               │
        │               │  Artifacts    │───────────────┘
        │               │  ├── *.whl    │
        │               │  ├── *.cosign.bundle │
        │               │  ├── checksums│
        │               │  └── sbom.json│
        │               └───────────────┘
        │
        └─► GitHub Releases (sthenos-security/reach-core)
            └─► Auto-sync to reach-dist/wheels/
```

---

## Wheel Directory Structure

```
reach-dist/
├── install.sh
├── VERIFICATION.md
├── CHANGELOG.md
├── RELEASING.md
├── README.md
└── wheels/
    ├── latest/                        → Symlink to most recent version
    └── v1.0.0b13/
        ├── checksums.sha256
        ├── VERIFICATION.md
        │
        │   Wheels (15 total)
        ├── reachable-1.0.0b13-cp310-cp310-linux_x86_64.whl
        ├── reachable-1.0.0b13-cp311-cp311-linux_x86_64.whl
        ├── ...
        │
        │   Cosign Bundles (1 per wheel)
        ├── reachable-1.0.0b13-cp310-cp310-linux_x86_64.whl.cosign.bundle
        ├── reachable-1.0.0b13-cp311-cp311-linux_x86_64.whl.cosign.bundle
        └── ...
```

---

## Wheel Matrix

Each release builds **15 wheels** (3 platforms × 5 Python versions):

| Platform | Architecture | Python 3.10 | Python 3.11 | Python 3.12 | Python 3.13 | Python 3.14 |
|----------|--------------|-------------|-------------|-------------|-------------|-------------|
| Linux | x86_64 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Linux | ARM64 | ✅ | ✅ | ✅ | ✅ | ✅ |
| macOS | Universal (Intel + Apple Silicon) | ✅ | ✅ | ✅ | ✅ | ✅ |

### Platform Tags

| Platform | Tag |
|----------|-----|
| Linux x86_64 | `linux_x86_64` |
| Linux ARM64 | `linux_aarch64` |
| macOS (Python 3.10-3.11) | `macosx_10_9_universal2` |
| macOS (Python 3.12-3.13) | `macosx_10_13_universal2` |
| macOS (Python 3.14) | `macosx_10_15_universal2` |

### Python Tags

| Python | Tag |
|--------|-----|
| 3.10 | `cp310` |
| 3.11 | `cp311` |
| 3.12 | `cp312` |
| 3.13 | `cp313` |
| 3.14 | `cp314` |

---

## Versioning

REACHABLE uses semantic versioning with beta releases:

| Version | Wheel Version | Example Wheel |
|---------|---------------|---------------|
| `1.0.0-beta13` | `1.0.0b13` | `reachable-1.0.0b13-cp312-cp312-linux_x86_64.whl` |
| `1.0.0` | `1.0.0` | `reachable-1.0.0-cp312-cp312-linux_x86_64.whl` |

**Version file:** `reachable/_version.py` in reach-core (e.g., `__version__ = "1.0.0b13"`)

---

## Cosign Signing

All wheels are signed using **keyless Sigstore cosign** via GitHub Actions OIDC. No long-lived signing keys exist.

Each wheel gets:
- `.cosign.bundle` — signature + certificate + Rekor log entry (single file)
- `.sig` — detached signature (legacy, kept for compatibility)
- `.crt` — ephemeral certificate (legacy, kept for compatibility)

Customers verify with:

```bash
cosign verify-blob \
    --bundle reachable-*.whl.cosign.bundle \
    --certificate-identity-regexp="https://github.com/sthenos-security/reach-core/.*" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    reachable-*.whl
```

See `VERIFICATION.md` for full customer-facing instructions.

---

## CI/CD Release Process

### Step 1: Prepare Version

```bash
cd ~/src/reach-core

# Update version
echo '__version__ = "1.0.0b14"' > reachable/_version.py

# Update CHANGELOG in reach-dist
# ... edit ~/src/reach-dist/CHANGELOG.md ...

# Commit
git add reachable/_version.py
git commit -m "bump version to 1.0.0b14"
git push origin refs/heads/main
```

### Step 2: Create Tag (Triggers CI/CD)

```bash
git tag v1.0.0b14
git push origin v1.0.0b14
```

This triggers `.github/workflows/release.yml` which:
1. Builds 15 wheels (3 platforms × 5 Python versions)
2. Runs validation tests (import, selftest, scan)
3. Signs all wheels with keyless cosign (OIDC)
4. Generates SHA256 checksums and SBOM
5. Creates GitHub Release on reach-core
6. Auto-syncs wheels + bundles to reach-dist (if `DIST_REPO_SYNC_TOKEN` set)

### Step 3: Monitor Build

Watch progress at: `https://github.com/sthenos-security/reach-core/actions`

Build takes approximately 15-20 minutes for all platforms.

### Step 4: Update reach-dist (if auto-sync not configured)

If `DIST_REPO_SYNC_TOKEN` is not set, manually sync:

```bash
cd ~/src/reach-dist

mkdir -p wheels/v1.0.0b14
# Copy wheels and bundles from reach-core release
gh release download v1.0.0b14 --repo sthenos-security/reach-core -D wheels/v1.0.0b14

cd wheels
rm -f latest
ln -s v1.0.0b14 latest
cd ..

# Update install.sh version
sed -i '' 's/VERSION="1.0.0b13"/VERSION="1.0.0b14"/' install.sh
sed -i '' 's/WHEEL_VERSION="1.0.0b13"/WHEEL_VERSION="1.0.0b14"/' install.sh

git add .
git commit -m "Release v1.0.0b14"
git push origin refs/heads/main
```

---

## Post-Release Checklist

### Verification

```bash
rm -rf ~/.reachable
./install.sh
reachctl version
reachctl selftest

# Verify cosign signature
cosign verify-blob \
    --bundle wheels/v1.0.0b14/reachable-*.whl.cosign.bundle \
    --certificate-identity-regexp="https://github.com/sthenos-security/reach-core/.*" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    wheels/v1.0.0b14/reachable-*.whl
```

### reach-dist Updates

- [ ] Wheels + cosign bundles in `wheels/vX.Y.ZbN/`
- [ ] `wheels/latest` symlink updated
- [ ] `install.sh` VERSION updated
- [ ] `CHANGELOG.md` updated
- [ ] `VERIFICATION.md` version examples current

### Communication

- [ ] Notify beta testers (if significant changes)

---

## Troubleshooting

### CI/CD Build Fails

1. Check Actions log: `https://github.com/sthenos-security/reach-core/actions`
2. Common issues:
   - YAML syntax error in `release.yml` — validate with `python3 -c "import yaml; yaml.safe_load(open('release.yml'))"`
   - Python version not available on runner
   - QEMU timeout for ARM64 builds
   - Dependency installation failures

### Tag Already Exists

```bash
git tag -d v1.0.0b13
git push origin :refs/tags/v1.0.0b13
git tag v1.0.0b13
git push origin v1.0.0b13
```

### "src refspec main matches more than one"

Ambiguous ref — branch and tag share a name. Use explicit ref:

```bash
git push origin refs/heads/main
```

### Wrong Version in Wheel

Check `_version.py` matches expected version before tagging:

```bash
cat reachable/_version.py
```

---

## Questions?

Contact: adazzi@sthenosec.com

---

© 2026 Sthenos Security. All rights reserved.
