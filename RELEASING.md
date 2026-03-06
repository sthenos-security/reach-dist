# Releasing REACHABLE

Internal documentation for the release process.

---

## Release Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   reach-core    │────►│  GitHub Actions │────►│   reach-dist    │
│   (source)      │     │   (CI/CD)       │     │   (distribution)│
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
        │               │  ├── *.whl    │  SSH deploy key
        │               │  └── checksums│  auto-pushed to
        │               └───────────────┘  wheels/v<tag>/
        │
        └─► GitHub Release (reach-core)
```

Wheels are built and pushed to reach-dist **automatically** by the release workflow. No manual copy step required.

---

## Wheel Directory Structure

```
reach-dist/
├── install.sh
├── wheels/
│   ├── latest/                      → Recreated on every release
│   └── v<tag>/                      → One directory per release
│       ├── checksums.sha256
│       │
│       │   Linux x86_64
│       ├── reachable-<ver>-cp310-cp310-linux_x86_64.whl
│       ├── reachable-<ver>-cp311-cp311-linux_x86_64.whl
│       ├── reachable-<ver>-cp312-cp312-linux_x86_64.whl
│       ├── reachable-<ver>-cp313-cp313-linux_x86_64.whl
│       ├── reachable-<ver>-cp314-cp314-linux_x86_64.whl
│       │
│       │   Linux ARM64
│       ├── reachable-<ver>-cp310-cp310-linux_aarch64.whl
│       ├── reachable-<ver>-cp311-cp311-linux_aarch64.whl
│       ├── reachable-<ver>-cp312-cp312-linux_aarch64.whl
│       ├── reachable-<ver>-cp313-cp313-linux_aarch64.whl
│       ├── reachable-<ver>-cp314-cp314-linux_aarch64.whl
│       │
│       │   macOS Universal (Intel + Apple Silicon)
│       ├── reachable-<ver>-cp310-cp310-macosx_10_9_universal2.whl
│       ├── reachable-<ver>-cp311-cp311-macosx_10_9_universal2.whl
│       ├── reachable-<ver>-cp312-cp312-macosx_10_13_universal2.whl
│       ├── reachable-<ver>-cp313-cp313-macosx_10_13_universal2.whl
│       └── reachable-<ver>-cp314-cp314-macosx_10_15_universal2.whl
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
| macOS (Python 3.10–3.11) | `macosx_10_9_universal2` |
| macOS (Python 3.12–3.13) | `macosx_10_13_universal2` |
| macOS (Python 3.14) | `macosx_10_15_universal2` |

All macOS wheels are `universal2` — support both Intel and Apple Silicon.

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

REACHABLE uses semantic versioning with PEP 440 beta suffixes:

| Git Tag | Wheel Version | Example Wheel |
|---------|---------------|---------------|
| `v<X.Y.Z-betaN>` | `<X.Y.Z>bN` | `reachable-<X.Y.Z>bN-cp311-cp311-linux_x86_64.whl` |
| `v<X.Y.Z>` | `<X.Y.Z>` | `reachable-<X.Y.Z>-cp311-cp311-linux_x86_64.whl` |

**Version file:** `VERSION` in reach-core root.

---

## CI/CD Release Process

### Step 1: Prepare Version

```bash
cd ~/src/reach-core

# Update version
echo "<new-version>" > VERSION

# Commit
git add VERSION
git commit -m "chore: bump version to <new-version>"
git push origin main
```

### Step 2: Tag (Triggers CI/CD)

```bash
git tag v<new-version>
git push origin v<new-version>
```

This triggers `.github/workflows/release.yml` which:
1. Validates the SSH deploy key
2. Builds 15 wheels across all platform/Python combinations
3. Signs each wheel with Cosign (keyless OIDC via Sigstore)
4. Generates SHA256 checksums
5. Creates a GitHub Release on reach-core with all artifacts
6. Pushes wheels to `reach-dist/wheels/v<tag>/` via SSH deploy key
7. Recreates `reach-dist/wheels/latest/` pointing to the new version

### Step 3: Monitor Build

Watch progress at: `https://github.com/sthenos-security/reach-core/actions`

Build takes approximately 15–20 minutes.

### Step 4: Verify

```bash
cd ~/src/reach-dist
git pull origin main
ls wheels/v<tag>/   # Should have 15 wheels + checksums.sha256
```

---

## Post-Release Checklist

- [ ] Tag pushed and release workflow succeeded
- [ ] `wheels/v<tag>/` contains all 15 wheels in reach-dist
- [ ] `wheels/latest/` updated
- [ ] `install.sh` end-to-end test: `curl -sL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash`
- [ ] `reachctl version` shows correct version
- [ ] `reachctl selftest` passes

---

## Troubleshooting

### CI/CD Build Fails

1. Check Actions log: `https://github.com/sthenos-security/reach-core/actions`
2. Common issues:
   - Python version not available on runner
   - QEMU timeout for ARM64 builds
   - SSH deploy key issue (check `validate-deploy-key` job)

### Tag Already Exists

```bash
git tag -d v<tag>
git push origin :refs/tags/v<tag>
git tag v<tag>
git push origin v<tag>
```

> **Note:** If repo rules prevent tag deletion, increment to the next version.

### Wrong Version in Wheel

```bash
cat VERSION   # Verify before tagging
```

---

## Questions?

Contact: info@sthenosec.com
