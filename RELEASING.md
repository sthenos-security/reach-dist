# Releasing REACHABLE

Internal documentation for the secure release process.

---

## Release Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   reach-core    │────►│   release.py    │────►│   reach-dist    │
│   (source)      │     │   (build+sign)  │     │   (distribute)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        │                       ▼                       │
        │               ┌───────────────┐               │
        │               │ • Nuitka      │               │
        │               │ • C extension │               │
        │               │ • Cosign      │               │
        │               │ • SBOM        │               │
        │               └───────────────┘               │
        │                       │                       │
        │                       ▼                       │
        │               ┌───────────────┐               │
        │               │  release/     │───────────────┘
        │               │  ├── *.whl    │
        │               │  ├── *.sig    │
        │               │  ├── *.crt    │
        │               │  └── sbom.json│
        │               └───────────────┘
        │
        └─► GitHub Releases (sthenos-security/reach-dist)
```

---

## Manual Release Process

### Step 1: Prepare

```bash
cd ~/src/reach-core

# Update version
echo "4.5.10" > VERSION

# Update CHANGELOG
# ... edit docs/CHANGELOG.md ...

# Commit
git add VERSION docs/CHANGELOG.md
git commit -m "Bump version to 4.5.10"
git tag v4.5.10
git push origin main --tags
```

### Step 2: Build and Sign

```bash
# Full release (Nuitka + cosign)
python release.py --clean

# This will:
# 1. Check prerequisites (nuitka, cosign, etc.)
# 2. Compile with Nuitka (source protection)
# 3. Build wheel with C license extension
# 4. Open browser for GitHub OIDC authentication
# 5. Sign wheel with cosign
# 6. Generate SHA256SUMS
# 7. Generate SBOM (if syft available)
# 8. Generate security-bulletin.md
```

### Step 3: Verify Locally

```bash
# Check the output
ls -la release/

# Verify your own signature
cosign verify-blob \
  --certificate release/reachable-*.whl.crt \
  --signature release/reachable-*.whl.sig \
  --certificate-identity-regexp "https://github.com/sthenos-security/.*" \
  --certificate-oidc-issuer "https://github.com/login/oauth" \
  release/reachable-*.whl

# Test installation
python3 -m venv test-env
source test-env/bin/activate
pip install release/reachable-*.whl
reachctl selftest
deactivate
rm -rf test-env
```

### Step 4: Upload to GitHub Releases

```bash
# Copy to reach-dist (optional, for local backup)
python release.py --copy-dist

# Upload to GitHub Releases
# 1. Go to: https://github.com/sthenos-security/reach-dist/releases
# 2. Click "Draft a new release"
# 3. Tag: v4.5.10
# 4. Title: REACHABLE v4.5.10
# 5. Upload all files from release/
# 6. Copy release notes from CHANGELOG
# 7. Publish release
```

---

## Build Options

```bash
# Full build (Nuitka + cosign)
python release.py

# Skip signing (for local testing)
python release.py --no-sign

# Skip Nuitka (faster, Cython only)
python release.py --no-nuitka

# Clean build
python release.py --clean

# Copy to reach-dist repo
python release.py --copy-dist
```

---

## What Gets Compiled

### Nuitka Compilation

All Python files are compiled to native `.so` files except:

| File | Treatment | Reason |
|------|-----------|--------|
| `__init__.py` | Kept as Python stub | Package structure |
| `__main__.py` | Kept as Python | Entry point |
| `*.py` | Compiled to `.so` | Source protection |

### C License Extension

The `_license.c` extension is always compiled:
- Validates 30-day evaluation period
- Platform-specific paths for license file
- Compiled separately from Nuitka

### Final Wheel Contents

```
reachable-4.5.10-cp311-cp311-macosx_14_0_arm64.whl
├── reachable/
│   ├── __init__.py              # Minimal stub
│   ├── cli.cpython-311-darwin.so
│   ├── reachable.cpython-311-darwin.so
│   ├── _license.cpython-311-darwin.so  # C extension
│   ├── guarddog_scanner.cpython-311-darwin.so
│   └── ...
├── reachable/dashboard_v2/
│   ├── template.html            # Data (not compiled)
│   └── ...
└── reachable-4.5.10.dist-info/
    ├── METADATA
    ├── WHEEL
    ├── RECORD
    └── entry_points.txt
```

---

## Cosign Identity

### Local Signing (Manual Release)

When you sign locally, cosign uses GitHub OAuth:

- **OIDC Issuer:** `https://github.com/login/oauth`
- **Identity:** Your GitHub username/email

Certificate will show:
```
URI:https://github.com/login/oauth
```

### CI Signing (Automated Release)

When signed in GitHub Actions:

- **OIDC Issuer:** `https://token.actions.githubusercontent.com`
- **Identity:** Workflow path

Certificate will show:
```
URI:https://github.com/sthenos-security/reach-core/.github/workflows/release.yml@refs/tags/v4.5.10
```

### Customer Verification

Customers verify with a regexp that accepts both:

```bash
--certificate-identity-regexp "https://github.com/sthenos-security/.*"
```

This matches:
- `https://github.com/sthenos-security/reach-core/...` (CI)
- Potentially local signing from org members

---

## Multi-Platform Builds

For releases targeting multiple platforms:

### Option 1: Build on Each Platform

```bash
# On macOS ARM
python release.py --clean
# → reachable-4.5.10-cp311-cp311-macosx_14_0_arm64.whl

# On macOS Intel
python release.py --clean
# → reachable-4.5.10-cp311-cp311-macosx_13_0_x86_64.whl

# On Linux x86_64
python release.py --clean
# → reachable-4.5.10-cp311-cp311-manylinux_2_28_x86_64.whl
```

### Option 2: Docker Cross-Compilation

```bash
# Build Linux wheels from macOS
python build_wheels.py --all
```

This uses manylinux Docker images for Linux builds.

---

## Troubleshooting

### Nuitka Compilation Fails

```bash
# Check C compiler
xcode-select -p  # macOS
gcc --version    # Linux

# Install Xcode tools (macOS)
xcode-select --install
```

### Cosign Opens Wrong Browser

```bash
# Set browser explicitly
export BROWSER=/Applications/Firefox.app/Contents/MacOS/firefox
python release.py
```

### Signature Doesn't Match Expected Identity

If signing locally, the certificate identity will be your GitHub OAuth, not the repo path. This is expected for manual releases.

For CI automation, ensure the workflow has:
```yaml
permissions:
  id-token: write
```

---

## Future: Automated CI Release

When ready to automate, create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags: ['v*']

permissions:
  contents: write
  id-token: write  # For cosign OIDC

jobs:
  release:
    runs-on: macos-14  # Build for ARM first
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          
      - name: Install dependencies
        run: pip install nuitka ordered-set zstandard wheel build
        
      - name: Install cosign
        uses: sigstore/cosign-installer@v3
        
      - name: Build and sign
        run: python release.py --clean
        
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: release/*
```

**Currently disabled** - using manual releases until build process is stable.

---

## Checklist

### Pre-Release
- [ ] Update VERSION
- [ ] Update CHANGELOG.md
- [ ] Run tests: `reachctl selftest --integration`
- [ ] Commit and tag

### Build
- [ ] Run `python release.py --clean`
- [ ] Verify signature locally
- [ ] Test wheel installation

### Publish
- [ ] Upload to GitHub Releases
- [ ] Update reach-dist README if needed
- [ ] Notify customers (if significant update)

### Post-Release
- [ ] Verify download works
- [ ] Verify signature verification works
- [ ] Update documentation if needed
