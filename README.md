# REACHABLE Distribution Repository

Official distribution repository for REACHABLE wheel packages.

---

## Quick Install

### Option 1: Clone and Run

```bash
git clone https://github.com/sthenos-security/reach-dist.git
cd reach-dist
./install.sh
```

The installer will prompt for GitHub authentication via `gh auth login`.

### Option 2: curl with Token

```bash
export GITHUB_TOKEN=ghp_your_token_here
curl -H "Authorization: token $GITHUB_TOKEN" \
  -sSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash
```

Requires a PAT with `repo` scope.

### Option 3: Local Wheel Install

Download both files from the repo, then:

```bash
./install.sh --wheel ./wheels/latest/reachable-1.0.0b10-cp311-cp311-macosx_10_9_universal2.whl
```

Pick the wheel matching your Python version and OS from `wheels/latest/`.

---

## Upgrading

### Standard Upgrade

```bash
./install.sh --update
```

This will:
1. Backup your existing data (`~/.reachable` → `~/.reachable.backup.YYYYMMDD-HHMMSS`)
2. Uninstall the previous version
3. Install the new version
4. Preserve your scan history and configuration

### Clean Upgrade (Recommended for Beta)

During beta, some releases may include breaking changes to the database schema:

```bash
./install.sh --clean
```

Or manually:

```bash
rm -rf ~/.reachable
./install.sh
```

> **⚠️ Beta Notice:** During the beta period, we recommend using `--clean` when upgrading between versions to avoid potential compatibility issues.

### Install Specific Version

```bash
./install.sh --version 1.0.0-beta10
```

### Installer Options

| Option | Description |
|--------|-------------|
| `--update`, `-u` | Upgrade existing installation (backs up data) |
| `--clean` | Remove existing data before install |
| `--version`, `-v` | Install specific version (e.g., `1.0.0-beta10`) |
| `--wheel`, `-w` | Install from local wheel file (skips GitHub auth) |
| `--help`, `-h` | Show help |

---

## Requirements

- **Python:** 3.10, 3.11, 3.12, 3.13, or 3.14
- **OS:** Linux or macOS
- **Architecture:** x86_64 or ARM64
- **GitHub Access:** Collaborator access to this repo + PAT with `repo` scope

---

## Post-Installation

### Verify Installation

```bash
reachctl version     # Check installed version
reachctl selftest    # Run self-diagnostics
reachctl primer      # Quick-start guide
reachctl doctor      # Check/install dependencies
```

### First Scan

```bash
reachctl scan /path/to/your/repo
```

---

## Data Storage

REACHABLE stores data in `~/.reachable/`:

```
~/.reachable/
├── scans/           # Scan history and results (per-repo databases)
├── cache/           # Cached SBOM and call graph data
└── config/          # Configuration files
```

### Backup Your Data

```bash
cp -r ~/.reachable ~/.reachable.backup
```

The `--update` flag does this automatically.

---

## Uninstall

```bash
pip3 uninstall reachable
rm -rf ~/.reachable
```

---

## Troubleshooting

### "Command not found: reachctl"

Ensure Python user bin is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Upgrade Issues

```bash
rm -rf ~/.reachable
./install.sh
```

### GitHub Authentication Fails

```bash
gh auth logout
gh auth login -h github.com -p https -w
```

---

## Version History

| Version | Date | Notes |
|---------|------|-------|
| 1.0.0-beta10 | 2026-01-18 | Dashboard v2 cleanup, JS fixes |
| 1.0.0-beta8 | 2026-01-13 | Dashboard v4.5.23, improved remediation UI |
| 1.0.0-beta7 | 2026-01-10 | Initial beta release |

See [CHANGELOG.md](CHANGELOG.md) for detailed release notes.

---

## Support

- **Email:** adazzi@sthenosec.com

---

© 2026 Sthenos Security. All rights reserved.
