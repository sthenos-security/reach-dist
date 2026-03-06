# REACHABLE by Sthenos Security

Reachability-aware security analysis for your codebase. REACHABLE combines software composition analysis, call graph reachability, and multi-signal correlation to eliminate noise and surface only what actually matters.

---

## What It Does

REACHABLE scans your repository and determines which vulnerabilities, secrets, and security issues are reachable from your application code — not just present in your dependencies.

**Scanners:**
- **CVE / SBOM** — Dependency vulnerabilities with reachability analysis
- **Secrets + CWE** — Hardcoded secrets and code-level weaknesses
- **Malware** — Malicious package detection
- **Package Health** — Abandoned, confused, or risky dependencies
- **IaC** — Kubernetes and Docker security misconfigurations
- **AI/LLM Security** — OWASP LLM Top 10 and MITRE ATLAS checks
- **DLP/PII** — Data exposure and privacy risk analysis

---

## Requirements

- Python 3.10, 3.11, 3.12, 3.13, or 3.14
- Linux (x86_64 or ARM64) or macOS (Intel or Apple Silicon)
- Internet access for CVE database updates

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash
```

### Installer Options

| Option | Description |
|--------|-------------|
| `--update`, `-u` | Upgrade existing installation (backs up data) |
| `--clean` | Remove existing data before install |
| `--version`, `-v` | Install a specific version |
| `--wheel`, `-w` | Install from a local wheel file |
| `--help`, `-h` | Show help |

### Upgrade

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --update
```

> **Beta Notice:** For beta releases, use `--clean` when upgrading to avoid database compatibility issues.

---

## Getting Started

```bash
reachctl version      # Verify installation
reachctl doctor       # Check and install dependencies
reachctl selftest     # Run self-diagnostics
reachctl primer       # Quick-start guide
```

### Run a Scan

```bash
reachctl scan /path/to/your/repo
```

---

## CI/CD Integration

Sample workflows for GitHub Actions, GitLab CI, and Jenkins are available in the `cicd-templates/` directory.

---

## Data Storage

REACHABLE stores data in `~/.reachable/`:

```
~/.reachable/
├── scans/     # Scan history and results
├── cache/     # Cached SBOM and call graph data
└── config/    # Configuration files
```

### Backup

```bash
cp -r ~/.reachable ~/.reachable.backup
```

The `--update` flag does this automatically before upgrading.

---

## Uninstall

```bash
pip uninstall reachable
rm -rf ~/.reachable
```

---

## Troubleshooting

### `reachctl: command not found`

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add this to your shell profile (`~/.zshrc` or `~/.bashrc`) to make it permanent.

---

## Support

Email: info@sthenosec.com

---

© 2026 Sthenos Security. All rights reserved.
