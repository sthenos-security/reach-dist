# REACHABLE by Sthenos Security

Most security scanners drown you in CVEs you'll never fix. REACHABLE cuts through the noise — it maps your call graph, traces data flow, and tells you exactly which vulnerabilities are reachable from your running code. Everything else gets deprioritized so your team fixes what actually matters.

One command. Seven concurrent scanners. Full interactive dashboard in 90 seconds.

---

## What You Get

REACHABLE performs multi-signal reachability analysis across your entire application stack and delivers results through an interactive, offline HTML dashboard.

**Security Analysis**
- **CVE / SBOM** — Dependency vulnerabilities correlated with call graph reachability. Know which CVEs your code can actually reach.
- **CWE** — Code-level weaknesses (injection, auth flaws, crypto misuse) with source-level tracing
- **Secrets** — Hardcoded credentials, API keys, and tokens with reachability context — is the secret actually used?
- **Malware** — Static pattern detection + behavioral sandbox analysis. Confirmed vs. suspicious verdicts with package-level attribution.
- **IaC / Config** — Kubernetes, Docker, and infrastructure misconfigurations mapped to compliance frameworks

**AI & LLM Security**
- **OWASP LLM Top 10** — Prompt injection, data poisoning, model theft, and 7 more categories with Agentic Security Index
- **AI Attack Surface** — Mapping of AI/ML entry points, model endpoints, and GenAI integration risks across your codebase

**Supply Chain**
- **Package Health** — Popularity, maintenance activity, and risk signals from npm, PyPI, and GitHub
- **Dependency Confusion** — Typosquatting and namespace confusion detection

**Data Protection**
- **DLP / PII** — Taint analysis for data exposure, PII leakage, and privacy risk across source code

**Governance & Visibility**
- **GRC / Compliance** — Automated mapping to FedRAMP, CMMC 2.0, NIST 800-53, SOC2, and PCI-DSS
- **Scan Coverage** — Per-scanner tool status, file coverage, and language breakdown
- **Risk & Posture** — Aggregate risk scoring with severity distribution, reachability breakdown, and trend tracking

---

## Supported Languages

**Full reachability analysis** (call graph tracing + all scanners):

Python, JavaScript, TypeScript, Go, Java

**Dependency & vulnerability scanning** (CVE, SBOM, secrets, IaC — reachability reported as UNKNOWN):

Rust, Ruby, PHP, C#/.NET, C/C++, Swift, Kotlin, Scala, and 30+ additional ecosystems via SBOM.

---

## Requirements

- Python 3.11, 3.12, 3.13, or 3.14
- Linux (x86_64 or ARM64) or macOS (Apple Silicon or Intel)
- Internet access for CVE database updates

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash
```

### Options

| Option | Description |
|--------|-------------|
| `--update`, `-u` | Upgrade existing installation (backs up data) |
| `--clean` | Remove existing data before install |
| `--version`, `-v` | Install a specific version |
| `--wheel`, `-w` | Install from a local wheel file |

### Upgrade

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --update
```

> **Beta Notice:** Use `--clean` when upgrading between beta releases to avoid database compatibility issues.

---

## Getting Started

### 1. Add to PATH

```bash
export PATH="$HOME/.reachable/venv/bin:$PATH"
```

Add to your `~/.zshrc` or `~/.bashrc` to make it permanent.

### 2. Install External Tools

```bash
reachctl doctor
```

Run once after installation. See [DOCTOR.md](DOCTOR.md) for details.

### 3. Scan

```bash
reachctl scan /path/to/your/repo
```

Dashboard opens automatically.

### Scan Options

| Flag | Effect |
|------|--------|
| `--debug` | Verbose output with timestamps |
| `--no-ai` | Skip AI/LLM analysis (faster) |
| `--no-dlp` | Skip DLP/PII analysis |
| `--ci --fail-on high` | CI mode with threshold gating |

### 4. Authentication (Recommended)

```bash
reachctl auth login
```

Stores GitHub and MCP tokens securely in the system keychain. See `reachctl primer` for token scopes and advanced options.

### Reference

```bash
reachctl primer       # Full interactive command reference
reachctl --help       # Quick overview
```

---

## Enzo — AI Remediation (Preview)

Enzo is REACHABLE's AI remediation engine. It reads scan findings, generates targeted patches, and optionally validates fixes with exploit payloads — all from the CLI.

```bash
reachctl enzo scan ~/src/myapp          # See what enzo can fix
reachctl enzo run ~/src/myapp --dry-run # Preview patches without applying
reachctl enzo run ~/src/myapp           # Apply fixes
reachctl enzo pentest ~/src/myapp       # Verify fixes with exploit payloads
```

Runs locally via Ollama (code never leaves your machine) or via Claude API. See `reachctl enzo --help`.

> Enzo is included as a preview in this beta. Full release targeted for a future version.

---

## CI/CD Integration

Ready-to-use templates for GitHub Actions, GitLab CI, and Jenkins:

```
cicd-templates/
├── github-actions/reachable.yml
├── gitlab/reachable.gitlab-ci.yml
└── jenkins/Jenkinsfile
```

Copy the relevant template into your repository. For full documentation and local testing scripts, see [reach-dist-cicd](https://github.com/sthenos-security/reach-dist-cicd).

---

## Release Verification

Every release is signed and checksummed. The installer verifies both automatically.

**SHA-256** — verified on every install. Mismatch aborts immediately.

**Cosign** — verified if `cosign` is installed. Keyless OIDC signatures via [Sigstore](https://sigstore.dev), tied to the GitHub Actions workflow that built the wheel.

Checksums and signature bundles for all releases are in `wheels/v<version>/`.

---

## Roadmap

Active development. Here's where we're headed:

- **Enzo GA** — AI remediation engine: automated fix generation, validation, and commit. Local (Ollama) and cloud (Claude API) modes.
- **RADR** — Runtime Application Detection & Response. Lightweight agent that monitors running workloads and correlates runtime behavior with static scan findings.
- **Additional languages and build systems** — Expanding call graph reachability analysis to more ecosystems.
- **Global intelligence cache** — Cross-scan knowledge graph that accelerates repeat scans and shares anonymized threat signals across deployments.
- **Multi-tenant SaaS dashboard** — Centralized visibility across teams, repos, and environments. Role-based access, trend analytics, and policy enforcement.

---

## Troubleshooting

### `reachctl: command not found`

```bash
export PATH="$HOME/.reachable/venv/bin:$PATH"
```

Add to `~/.zshrc` or `~/.bashrc` to make it permanent.

### `Error resolving latest version`

- **Version not yet published.** A new release may still be building. Wait a few minutes and retry.
- **GitHub API rate limit.** Pass a token: `export GITHUB_TOKEN="ghp_yourtoken"` then re-run the installer.
- **Network issue.** Verify you can reach `api.github.com`.

If the problem persists, contact info@sthenosec.com.

---

## Support

Email: info@sthenosec.com

---

© 2026 Sthenos Security. All rights reserved.
