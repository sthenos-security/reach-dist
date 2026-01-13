# REACHABLE Distribution Repository

Official distribution repository for REACHABLE wheel packages.

---

## Quick Install

### Option 1: Automated Install (Recommended)

```bash
# Download installer
curl -LO https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh

# Make executable (just in case)
chmod +x install.sh

# Run installer
./install.sh
```

The installer will:
1. Prompt for your GitHub Personal Access Token
2. Auto-detect your OS, architecture, and Python version
3. Download and install the correct wheel
4. Create an isolated virtual environment at `~/.reachable/venv`

**GitHub Token Setup:**
- Go to https://github.com/settings/tokens
- Create a **Classic** token with `repo` scope enabled
- Or set `export GITHUB_TOKEN=ghp_xxx` before running

### Option 2: Manual Wheel Install

If you prefer to download the wheel manually:

```bash
# Download install.sh and your wheel
curl -LO https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh
chmod +x install.sh

# Install from local wheel (no GitHub token needed)
./install.sh path/to/reachable-1.0.0b7-cpXYZ-cpXYZ-PLATFORM.whl
```

Wheels are available in:
- `wheels/latest/` — Latest release
- `wheels/v1.0.0-beta7/` — Specific version

---

## Requirements

- **Python:** 3.10, 3.11, 3.12, 3.13, or 3.14
- **OS:** Linux or macOS
- **Architecture:** x86_64 or ARM64 (macOS wheels are universal - work on both)

---

## Post-Installation

### Add to PATH

After installation, add the REACHABLE bin directory to your PATH:

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.reachable/venv/bin:$PATH"

# Reload shell
source ~/.zshrc  # or ~/.bashrc
```

### Verify Installation

```bash
reachctl version
reachctl selftest
reachctl primer    # Quick-start guide
```

### Check Dependencies

```bash
reachctl doctor
```

---

## Wheel Matrix (v1.0.0-beta7)

Each release includes **15 wheels** (5 Python versions × 3 platforms):

### Linux

| Python | x86_64 | ARM64 |
|--------|--------|-------|
| 3.10 | `reachable-1.0.0b7-cp310-cp310-linux_x86_64.whl` | `reachable-1.0.0b7-cp310-cp310-linux_aarch64.whl` |
| 3.11 | `reachable-1.0.0b7-cp311-cp311-linux_x86_64.whl` | `reachable-1.0.0b7-cp311-cp311-linux_aarch64.whl` |
| 3.12 | `reachable-1.0.0b7-cp312-cp312-linux_x86_64.whl` | `reachable-1.0.0b7-cp312-cp312-linux_aarch64.whl` |
| 3.13 | `reachable-1.0.0b7-cp313-cp313-linux_x86_64.whl` | `reachable-1.0.0b7-cp313-cp313-linux_aarch64.whl` |
| 3.14 | `reachable-1.0.0b7-cp314-cp314-linux_x86_64.whl` | `reachable-1.0.0b7-cp314-cp314-linux_aarch64.whl` |

### macOS (Universal - Intel + Apple Silicon)

| Python | Wheel | Min macOS |
|--------|-------|-----------|
| 3.10 | `reachable-1.0.0b7-cp310-cp310-macosx_10_9_universal2.whl` | 10.9 |
| 3.11 | `reachable-1.0.0b7-cp311-cp311-macosx_10_9_universal2.whl` | 10.9 |
| 3.12 | `reachable-1.0.0b7-cp312-cp312-macosx_10_13_universal2.whl` | 10.13 |
| 3.13 | `reachable-1.0.0b7-cp313-cp313-macosx_10_13_universal2.whl` | 10.13 |
| 3.14 | `reachable-1.0.0b7-cp314-cp314-macosx_10_15_universal2.whl` | 10.15 |

> **Note:** All macOS wheels are `universal2` and work on **both** Intel and Apple Silicon Macs.

---

## GitHub Authentication for Scanning

After installation, REACHABLE needs GitHub access to clone vulnerable library source code for reachability analysis. This requires **read permissions on all repositories** (public and private).

### Option 1: SSH Key (Recommended for Developers)

```bash
# Check if SSH is configured
ssh -T git@github.com

# If not, generate a key and add to GitHub
ssh-keygen -t ed25519
# Add ~/.ssh/id_ed25519.pub to https://github.com/settings/keys
```

### Option 2: GitHub Token (Recommended for CI/CD)

```bash
export GITHUB_TOKEN='ghp_your_token_here'
```

**Required scope:** `repo` (grants read access to public AND private repositories)

### Option 3: MCP GitHub Token (Claude Desktop Integration)

```bash
export MCP_GITHUB_TOKEN='ghp_your_token_here'
```

**Same scope requirements** - needs `repo` scope for full read access.

Used for MCP-based cloning. Falls back to regular git if unavailable.

### Token Priority

1. `MCP_GITHUB_TOKEN`
2. `GITHUB_TOKEN`
3. `GH_TOKEN`
4. SSH key

---

## Uninstall

```bash
# Remove the virtual environment and all data
rm -rf ~/.reachable
```

---

## Reinstall / Upgrade

The installer uses `--force-reinstall`, so you can simply re-run it:

```bash
# Re-run installer (automatically replaces existing installation)
./install.sh
```

For a completely clean reinstall:

```bash
# Remove existing installation first
rm -rf ~/.reachable

# Run installer
./install.sh
```

---

## Troubleshooting

### "Command not found: reachctl"

Add REACHABLE's venv bin directory to your PATH:

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.reachable/venv/bin:$PATH"

# Reload
source ~/.zshrc
```

### "No matching distribution found"

Ensure you're downloading the correct wheel for your Python version:

```bash
# Check Python version
python3 -c "import sys; print(f'cp{sys.version_info.major}{sys.version_info.minor}')"
```

### Permission Errors

```bash
rm -rf ~/.reachable
./install.sh
```

### Token Issues

If the installer fails with token errors:
1. Ensure you're using a **Classic** PAT (not fine-grained)
2. Verify the `repo` scope is enabled
3. Check if SSO authorization is required for your organization

---

## Support

- **Email:** adazzi@sthenosec.com
- **Documentation:** [reach-core/docs](https://github.com/sthenos-security/reach-core/tree/main/docs)

---

© 2026 Sthenos Security. All rights reserved.
