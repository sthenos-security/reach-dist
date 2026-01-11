# REACHABLE Distribution Repository

Official distribution repository for REACHABLE wheel packages.

---

## Quick Install

1. Download `install.sh` from this repository (Releases or Code tab)
2. Run it:

```bash
bash install.sh
```

3. Enter your GitHub Personal Access Token when prompted
   - Create one at: https://github.com/settings/tokens (with `repo` scope)
   - Or set `export GITHUB_TOKEN=ghp_xxx` before running

The installer auto-detects your OS, architecture, and Python version, then downloads the correct wheel.

---

## Requirements

- **Python:** 3.10, 3.11, 3.12, 3.13, or 3.14
- **OS:** Linux or macOS
- **Architecture:** x86_64 (Linux only) or ARM64

> **Note:** macOS Intel is not currently supported. Contact adazzi@sthenosec.com if needed.

---

## Manual Installation

If you prefer to install manually:

### 1. Check your Python version

```bash
python3 --version
```

### 2. Download the matching wheel

Find your wheel in the [Releases](https://github.com/sthenos-security/reach-dist/releases) page based on your Python version and platform.

### 3. Install

```bash
pip install reachable-<version>-<python>-<python>-<platform>.whl
```

### 4. Verify

```bash
reachctl version
reachctl selftest
```

---

## Wheel Naming Convention

```
reachable-VERSION-cpXYZ-cpXYZ-PLATFORM.whl
         │        │           │
         │        │           └── Platform tag
         │        └────────────── Python version tag (appears twice)
         └─────────────────────── Package version
```

### Python Version Tags

| Tag | Python Version |
|-----|----------------|
| `cp310` | Python 3.10 |
| `cp311` | Python 3.11 |
| `cp312` | Python 3.12 |
| `cp313` | Python 3.13 |
| `cp314` | Python 3.14 |

### Platform Tags

| Tag | Platform | Architecture |
|-----|----------|--------------|
| `manylinux_2_28_x86_64` | Linux | x86_64 (Intel/AMD) |
| `manylinux_2_28_aarch64` | Linux | ARM64 |
| `macosx_14_0_arm64` | macOS | Apple Silicon (M1/M2/M3/M4) |

> **Note:** macOS Intel wheels are not currently available. Intel Mac users can install from source.

---

## Wheel Matrix

Each release includes **15 wheels** (5 Python versions × 3 platforms):

| Platform | Architecture | cp310 | cp311 | cp312 | cp313 | cp314 |
|----------|--------------|-------|-------|-------|-------|-------|
| Linux | x86_64 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Linux | ARM64 | ✅ | ✅ | ✅ | ✅ | ✅ |
| macOS | Apple Silicon | ✅ | ✅ | ✅ | ✅ | ✅ |
| macOS | Intel | ❌ | ❌ | ❌ | ❌ | ❌ |

### Examples

| System | Python | Wheel |
|--------|--------|-------|
| Ubuntu 22.04, Intel | 3.11 | `reachable-*-cp311-cp311-manylinux_2_28_x86_64.whl` |
| Ubuntu 24.04, ARM (AWS Graviton) | 3.12 | `reachable-*-cp312-cp312-manylinux_2_28_aarch64.whl` |
| macOS Sonoma, M3 | 3.13 | `reachable-*-cp313-cp313-macosx_14_0_arm64.whl` |

---

## Post-Installation

### Quick Start Guide

```bash
reachctl primer
```

### Check Dependencies

```bash
reachctl doctor
```

### Scan a Repository

```bash
reachctl scan /path/to/your/repo
```

### View Dashboard

```bash
reachctl dashboard
```

---

## Uninstall

```bash
pip uninstall reachable
rm -rf ~/.reachable  # Optional: remove data
```

---

## Troubleshooting

### "Command not found: reachctl"

Add pip's bin directory to your PATH:

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"
```

### "No matching distribution found"

Ensure you're downloading the correct wheel for your Python version and platform:

```bash
# Check Python version
python3 -c "import sys; print(f'cp{sys.version_info.major}{sys.version_info.minor}')"

# Check platform
python3 -c "import platform; print(platform.machine())"
```

### Permission Errors

Use a virtual environment:

```bash
python3 -m venv ~/.reachable-venv
source ~/.reachable-venv/bin/activate
pip install <wheel-file>.whl
```

---

## Support

- **Email:** adazzi@sthenosec.com
- **Documentation:** [reach-core/docs](https://github.com/sthenos-security/reach-core/tree/main/docs)

---

© 2026 Sthenos Security. All rights reserved.
