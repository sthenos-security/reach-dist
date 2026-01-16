# REACHABLE Distribution Repository

Official distribution repository for REACHABLE wheel packages.

---

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash
```

The installer will:
1. Check for GitHub CLI (`gh`) and install if needed
2. Authenticate with GitHub (browser-based, secure)
3. Auto-detect your OS, architecture, and Python version
4. Download and install the correct wheel

---

## Upgrading

### Standard Upgrade

To upgrade from one beta version to another:

```bash
curl -sSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --update
```

This will:
1. Backup your existing data (`~/.reachable` → `~/.reachable.backup.YYYYMMDD-HHMMSS`)
2. Uninstall the previous version
3. Install the new version
4. Preserve your scan history and configuration

### Clean Upgrade (Recommended for Beta)

During beta, some releases may include breaking changes to the database schema. If you encounter issues after upgrading, perform a clean install:

```bash
# Option 1: Use --clean flag (removes data, then installs)
curl -sSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --clean

# Option 2: Manual clean install
rm -rf ~/.reachable
curl -sSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash
```

> **⚠️ Beta Notice:** During the beta period, we recommend using `--clean` when upgrading between versions to avoid potential compatibility issues. Your scan history will be reset, but this ensures a stable experience.

### Install Specific Version

```bash
curl -sSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --version 1.0.0-beta8
```

### Installer Options

| Option | Description |
|--------|-------------|
| `--update`, `-u` | Upgrade existing installation (backs up data) |
| `--clean` | Remove existing data before install |
| `--version`, `-v` | Install specific version (e.g., `1.0.0-beta9`) |
| `--help`, `-h` | Show help |

---

## Requirements

- **Python:** 3.10, 3.11, 3.12, 3.13, or 3.14
- **OS:** Linux or macOS
- **Architecture:** x86_64 or ARM64
- **GitHub CLI:** Installed automatically if missing

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

### Data Retention

- Scans are retained for 30 days by default
- Maximum 30 scans per branch
- Use `reachctl db trim` to manually clean old data

### Backup Your Data

```bash
# Manual backup
cp -r ~/.reachable ~/.reachable.backup

# The --update flag does this automatically
```

---

## GitHub Authentication

REACHABLE needs GitHub access to clone vulnerable library source code for reachability analysis.

### Recommended: GitHub CLI (Automatic)

The installer uses GitHub CLI for authentication. If not installed, it will be set up automatically.

```bash
# Check authentication status
gh auth status

# Re-authenticate if needed
gh auth login
```

### Alternative: Environment Variables

```bash
# For CI/CD or automation
export GITHUB_TOKEN='ghp_your_token_here'
```

**Required scope:** `repo` (grants read access to public AND private repositories)

---

## Uninstall

```bash
# Remove everything
rm -rf ~/.reachable

# Uninstall package
pip3 uninstall reachable
```

---

## Troubleshooting

### "Command not found: reachctl"

The package installs to your Python user bin. Ensure it's in your PATH:

```bash
# Check where it installed
pip3 show reachable | grep Location

# Usually need to add to PATH
export PATH="$HOME/.local/bin:$PATH"
```

### Upgrade Issues

If you encounter errors after upgrading:

```bash
# Clean install (removes data)
rm -rf ~/.reachable
curl -sSL .../install.sh | bash
```

### GitHub Authentication Fails

```bash
# Re-authenticate
gh auth logout
gh auth login -h github.com -p https -w
```

### Database Errors

During beta, database schema may change between versions:

```bash
# Reset database
rm -rf ~/.reachable/scans
reachctl scan /path/to/repo  # Will recreate
```

---

## Version History

| Version | Date | Notes |
|---------|------|-------|
| 1.0.0-beta10 | 2026-01-16 | Fix dashboard reachability mapping |
| 1.0.0-beta8 | 2026-01-13 | Dashboard v4.5.23, improved remediation UI |
| 1.0.0-beta7 | 2026-01-10 | Initial beta release |

See [CHANGELOG.md](CHANGELOG.md) for detailed release notes.

---

## Support

- **Email:** adazzi@sthenosec.com
- **Issues:** [GitHub Issues](https://github.com/sthenos-security/reach-dist/issues)

---

© 2026 Sthenos Security. All rights reserved.
