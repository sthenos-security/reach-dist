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

## Release Verification

Every REACHABLE release is signed and checksummed. The installer verifies both automatically before installing anything.

**SHA-256 checksum** — verified on every install. If the checksum does not match, the installer aborts immediately.

**Cosign signature** — verified if `cosign` is installed. Each wheel is signed via [Sigstore](https://sigstore.dev) keyless signing tied to the GitHub Actions workflow that built it, providing a tamper-proof audit trail from source to binary.

To verify manually:

```bash
# SHA-256
sha256sum --check checksums.sha256

# Cosign (requires cosign installed)
cosign verify-blob \
  --bundle reachable-<version>-<platform>.whl.cosign.bundle \
  --certificate-identity-regexp "https://github.com/sthenos-security/" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  reachable-<version>-<platform>.whl
```

Checksums and bundles for all releases are in `wheels/v<version>/`.

---

## Getting Started

### 1. Add to PATH

The installer puts `reachctl` in `~/.reachable/venv/bin/`. Add it to your PATH — **required before running any command**:

```bash
export PATH="$HOME/.reachable/venv/bin:$PATH"
```

To make it permanent, add the line above to your `~/.zshrc` or `~/.bashrc`, then restart your shell.

### 2. Install Dependencies

```bash
reachctl doctor
```

This installs the scanning tools (Syft, Grype, GuardDog). Run it once after installation.

### 3. Run a Scan

```bash
reachctl scan /path/to/your/repo
```

That's it. REACHABLE will scan your repository and open an interactive dashboard with the results.

### 4. Set Up Authentication (Recommended)

For full scan capability, store your GitHub and MCP tokens securely in the system keychain — do not set them as environment variables:

```bash
reachctl auth login
```

This prompts for your GitHub token and MCP token and stores them securely. Tokens set this way take precedence over environment variables and are never exposed in shell history or process listings.

See `reachctl primer` for token scopes, CI/CD setup, and advanced auth options.

### What's Next

```bash
reachctl primer       # Full command reference and advanced options
reachctl --help       # Quick command overview
```

---

## CI/CD Integration

Ready-to-use templates for GitHub Actions, GitLab CI, and Jenkins are included in [`cicd-templates/`](cicd-templates/):

```
cicd-templates/
├── github-actions/
├── gitlab/
└── jenkins/
```

Copy the relevant template into your repository and adjust the `FAIL_THRESHOLD` as needed.

---

## Data Storage

REACHABLE stores data in `~/.reachable/`:

```
~/.reachable/
├── scans/     # Scan history and results
├── cache/     # Cached data
└── config/    # Configuration files
```

---

## Uninstall

```bash
~/.reachable/venv/bin/pip uninstall reachable
rm -rf ~/.reachable
```

---

## Troubleshooting

### `reachctl: command not found`

```bash
export PATH="$HOME/.reachable/venv/bin:$PATH"
```

Add this to your `~/.zshrc` or `~/.bashrc` to make it permanent.

---

## Support

Email: info@sthenosec.com

---

© 2026 Sthenos Security. All rights reserved.
