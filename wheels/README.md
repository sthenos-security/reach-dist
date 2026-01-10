# Wheels Directory

This directory is for **local development** only.

**Production wheels are distributed via GitHub Releases:**
https://github.com/sthenos-security/reach-dist/releases

---

## Why GitHub Releases?

- Binary files don't belong in git history
- GitHub Releases provides versioned download URLs
- Releases can be tagged and organized by version

---

## Local Testing

During development, you can place test wheels here:

```bash
# Build wheel in reach-core
cd ~/src/reach-core
python release.py --no-sign

# Copy to test
cp release/*.whl ~/src/reach-dist/wheels/

# Test install
cd ~/src/reach-dist
./install.sh wheels/reachable-4.5.9-*.whl
```

---

## Production Release

For production releases:

1. Build and sign in reach-core: `python release.py`
2. Upload to GitHub Releases (not this directory)
3. Customers download from releases page

See [RELEASING.md](../RELEASING.md) for full process.
