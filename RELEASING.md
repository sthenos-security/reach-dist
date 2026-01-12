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
            └─► Copy to reach-dist/wheels/
```

---

## Wheel Directory Structure

```
reach-dist/
├── install.sh                    → Automated installer
├── wheels/
│   ├── latest/                   → Symlink to most recent version
│   └── v1.0.0-beta7/             → Version-specific directory
│       ├── checksums.sha256
│       │
│       │   Linux x86_64
│       ├── reachable-1.0.0b7-cp310-cp310-linux_x86_64.whl
│       ├── reachable-1.0.0b7-cp311-cp311-linux_x86_64.whl
│       ├── reachable-1.0.0b7-cp312-cp312-linux_x86_64.whl
│       ├── reachable-1.0.0b7-cp313-cp313-linux_x86_64.whl
│       ├── reachable-1.0.0b7-cp314-cp314-linux_x86_64.whl
│       │
│       │   Linux ARM64
│       ├── reachable-1.0.0b7-cp310-cp310-linux_aarch64.whl
│       ├── reachable-1.0.0b7-cp311-cp311-linux_aarch64.whl
│       ├── reachable-1.0.0b7-cp312-cp312-linux_aarch64.whl
│       ├── reachable-1.0.0b7-cp313-cp313-linux_aarch64.whl
│       ├── reachable-1.0.0b7-cp314-cp314-linux_aarch64.whl
│       │
│       │   macOS Universal (Intel + Apple Silicon)
│       ├── reachable-1.0.0b7-cp310-cp310-macosx_10_9_universal2.whl
│       ├── reachable-1.0.0b7-cp311-cp311-macosx_10_9_universal2.whl
│       ├── reachable-1.0.0b7-cp312-cp312-macosx_10_13_universal2.whl
│       ├── reachable-1.0.0b7-cp313-cp313-macosx_10_13_universal2.whl
│       └── reachable-1.0.0b7-cp314-cp314-macosx_10_15_universal2.whl
└── README.md
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

> **Note:** All macOS wheels are `universal2`, supporting both Intel and Apple Silicon Macs.

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
| `1.0.0-beta7` | `1.0.0b7` | `reachable-1.0.0b7-cp311-cp311-macosx_10_9_universal2.whl` |
| `1.0.0-beta8` | `1.0.0b8` | `reachable-1.0.0b8-cp312-cp312-linux_x86_64.whl` |
| `1.0.0` | `1.0.0` | `reachable-1.0.0-cp311-cp311-linux_aarch64.whl` |

**Version file:** `VERSION` in reach-core root (e.g., `1.0.0b7`)

---

## CI/CD Release Process

### Step 1: Prepare Version

```bash
cd ~/src/reach-core

# Update version
echo "1.0.0b8" > VERSION

# Update CHANGELOG
# ... edit docs/CHANGELOG.md ...

# Commit
git add VERSION docs/CHANGELOG.md
git commit -m "v1.0.0-beta8"
git push origin main
```

### Step 2: Create Tag (Triggers CI/CD)

```bash
# Create and push tag
git tag -a v1.0.0-beta8 -m "15 wheels"
git push origin v1.0.0-beta8
```

This triggers `.github/workflows/release.yml` which:
1. Builds wheels for all 15 platform/Python combinations
2. Generates SHA256 checksums
3. Generates SBOM (if configured)
4. Creates GitHub Release with all artifacts

### Step 3: Monitor Build

Watch progress at: `https://github.com/sthenos-security/reach-core/actions`

Build takes approximately 15-20 minutes for all platforms.

### Step 4: Copy to reach-dist

After CI/CD completes, copy wheels to reach-dist:

```bash
cd ~/src/reach-dist

# Create version directory
mkdir -p wheels/v1.0.0-beta8

# Download wheels from reach-core release (or copy from CI artifacts)
# ... copy wheels to wheels/v1.0.0-beta8/ ...

# Update latest symlink
cd wheels
rm -f latest
ln -s v1.0.0-beta8 latest
cd ..

# Update install.sh version
sed -i '' 's/VERSION="1.0.0-beta7"/VERSION="1.0.0-beta8"/' install.sh

# Commit and push
git add .
git commit -m "Release v1.0.0-beta8"
git push origin main
```

---

## Post-Release Checklist

### Verification

```bash
# Clean install test
rm -rf ~/.reachable
./install.sh

# Verify installation
reachctl version
reachctl selftest
```

### Update reach-dist

- [ ] Copy wheels to `wheels/vX.Y.Z-betaN/`
- [ ] Update `wheels/latest` symlink
- [ ] Update `install.sh` VERSION
- [ ] Update `README.md` if needed
- [ ] Commit and push

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
git tag -d v1.0.0-beta7
git push origin --delete v1.0.0-beta7

# Re-create
git tag -a v1.0.0-beta7 -m "15 wheels"
git push origin v1.0.0-beta7
```

> **Note:** If repository rules prevent tag deletion, increment to next beta version.

### Wrong Version in Wheel

Check `VERSION` file matches expected version before tagging:

```bash
cat VERSION
# Should show: 1.0.0b7
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
