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
        │               │  ├── checksums│
        │               │  └── sbom.json│
        │               └───────────────┘
        │
        └─► GitHub Releases (sthenos-security/reach-core)
            └─► Copy to reach-dist releases
```

---

## Wheel Matrix

Each release builds **15 wheels** (3 platforms × 5 Python versions):

| Platform | Architecture | Python 3.10 | Python 3.11 | Python 3.12 | Python 3.13 | Python 3.14 |
|----------|--------------|-------------|-------------|-------------|-------------|-------------|
| Linux | x86_64 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Linux | ARM64 | ✅ | ✅ | ✅ | ✅ | ✅ |
| macOS | Apple Silicon | ✅ | ✅ | ✅ | ✅ | ✅ |

> **Note:** macOS Intel wheels are not currently available (GitHub retired Intel Mac runners).

### Platform Tags

| Platform | Tag |
|----------|-----|
| Linux x86_64 | `manylinux_2_28_x86_64` |
| Linux ARM64 | `manylinux_2_28_aarch64` |
| macOS Apple Silicon | `macosx_14_0_arm64` |

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
| `1.0.0-beta4` | `1.0.0b4` | `reachable-1.0.0b4-cp311-cp311-macosx_14_0_arm64.whl` |
| `1.0.0-beta5` | `1.0.0b5` | `reachable-1.0.0b5-cp312-cp312-manylinux_2_28_x86_64.whl` |
| `1.0.0` | `1.0.0` | `reachable-1.0.0-cp311-cp311-manylinux_2_28_aarch64.whl` |

**Version file:** `VERSION` in reach-core root (e.g., `1.0.0b4`)

---

## CI/CD Release Process

### Step 1: Prepare Version

```bash
cd ~/src/reach-core

# Update version
echo "1.0.0b5" > VERSION

# Update CHANGELOG
# ... edit docs/CHANGELOG.md ...

# Commit
git add VERSION docs/CHANGELOG.md
git commit -m "v1.0.0-beta5"
git push origin main
```

### Step 2: Create Tag (Triggers CI/CD)

```bash
# Create and push tag
git tag -a v1.0.0-beta5 -m "15 wheels"
git push origin v1.0.0-beta5
```

This triggers `.github/workflows/release.yml` which:
1. Builds wheels for all 15 platform/Python combinations
2. Generates SHA256 checksums
3. Generates SBOM (if configured)
4. Creates GitHub Release with all artifacts

### Step 3: Monitor Build

Watch progress at: `https://github.com/sthenos-security/reach-core/actions`

Build takes approximately 15-20 minutes for all platforms.

### Step 4: Copy to reach-dist (Optional)

For public distribution via reach-dist:

```bash
cd ~/src/reach-dist

# Update install.sh version
sed -i '' 's/VERSION="1.0.0-beta4"/VERSION="1.0.0-beta5"/' install.sh
sed -i '' 's/WHEEL_VERSION="1.0.0b4"/WHEEL_VERSION="1.0.0b5"/' install.sh

# Commit
git add install.sh
git commit -m "Update to v1.0.0-beta5"
git push origin main
```

Then create a matching release in reach-dist with the same wheel files.

---

## CI/CD Workflow Details

The release workflow (`.github/workflows/release.yml`) runs on tag push:

```yaml
on:
  push:
    tags: ['v*']
```

### Build Matrix

```yaml
matrix:
  include:
    # Linux x86_64
    - { os: ubuntu-latest, python: "3.10", platform: manylinux_2_28_x86_64 }
    - { os: ubuntu-latest, python: "3.11", platform: manylinux_2_28_x86_64 }
    # ... (15 total combinations)
    
    # Linux ARM64 (QEMU emulation)
    - { os: ubuntu-latest, python: "3.10", platform: manylinux_2_28_aarch64, emulate: true }
    
    # macOS Apple Silicon
    - { os: macos-14, python: "3.10", platform: macosx_14_0_arm64 }
```

### Artifacts Generated

| File | Description |
|------|-------------|
| `reachable-*.whl` | Python wheel (15 per release) |
| `checksums.sha256` | SHA256 checksums for all wheels |
| `sbom-*.json` | SBOM in SPDX format (optional) |

---

## Manual Release (Fallback)

If CI/CD fails, build locally:

### Prerequisites

```bash
# Install build tools
pip install build wheel

# For Linux wheels (from macOS)
# Use Docker with manylinux image
```

### Build Single Wheel

```bash
cd ~/src/reach-core
python -m build --wheel
# Output: dist/reachable-1.0.0b5-cp311-cp311-macosx_14_0_arm64.whl
```

### Upload to GitHub

1. Go to: `https://github.com/sthenos-security/reach-core/releases`
2. Edit the release (or create new)
3. Upload wheel files
4. Update checksums

---

## Post-Release Checklist

### Verification

```bash
# Download and test
pip install https://github.com/sthenos-security/reach-dist/releases/download/v1.0.0-beta5/reachable-1.0.0b5-cp311-cp311-macosx_14_0_arm64.whl

# Verify installation
reachctl version
reachctl selftest
```

### Update reach-dist

- [ ] Update `install.sh` version
- [ ] Update `README.md` if needed
- [ ] Create matching release (or sync from reach-core)

### Communication

- [ ] Update documentation if needed
- [ ] Notify beta testers (if significant changes)

---

## Troubleshooting

### CI/CD Build Fails

1. Check Actions log: `https://github.com/sthenos-security/reach-core/actions`
2. Common issues:
   - Python version not available on runner
   - QEMU timeout for ARM64 builds
   - Dependency installation failures

### Tag Already Exists

```bash
# Delete local and remote tag
git tag -d v1.0.0-beta5
git push origin --delete v1.0.0-beta5

# Re-create
git tag -a v1.0.0-beta5 -m "15 wheels"
git push origin v1.0.0-beta5
```

> **Note:** If repository rules prevent tag deletion, increment to next beta version.

### Wrong Version in Wheel

Check `VERSION` file matches expected version before tagging:

```bash
cat VERSION
# Should show: 1.0.0b5
```

---

## Future: Cosign Signing

Planned for P2.10 (see ROADMAP.md):

- Keyless OIDC signing via GitHub Actions
- Signature files (`.sig`) and certificates (`.crt`) for each wheel
- Rekor transparency log entries
- Customer verification instructions

---

## Questions?

Contact: adazzi@sthenosec.com
