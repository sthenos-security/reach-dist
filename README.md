# REACHABLE by Sthenos Security

REACHABLE performs deep code analysis and tells you exactly which vulnerabilities are reachable from your running code. Fix what matters, ignore what doesn't.

One command. Multi-signal reachability analysis. Full interactive dashboard in 90 seconds.

---

## What You Get

REACHABLE performs multi-signal reachability analysis across your entire application stack and delivers results through an interactive, offline HTML dashboard.

**Security Analysis**
- **CVE / SBOM** — Dependency vulnerabilities with reachability analysis. Know which CVEs your code can actually reach.
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
- **Scan Coverage** — Per-signal tool status, file coverage, and language breakdown
- **Risk & Posture** — Aggregate risk scoring with severity distribution, reachability breakdown, and trend tracking

---

## Supported Languages

Python, JavaScript/TypeScript, Go, Java

Full analysis — CVE reachability, CWE, secrets, malware, supply chain, AI/LLM, DLP — works across these languages. Additional languages and build systems are on the [roadmap](#roadmap).

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

## CI/CD Integration

Ready-to-use templates for GitHub Actions, GitLab CI, and Jenkins:

| Platform | Template | Copy to |
|---|---|---|
| GitHub Actions | [reach-testbed-github](https://github.com/sthenos-security/reach-testbed-github) | `.github/workflows/reachable.yml` |
| GitLab CI | [reach-testbed-gitlab](https://gitlab.com/sthenos-security/reach-testbed-gitlab) | `.gitlab-ci.yml` (repo root) |
| Jenkins | [`Jenkinsfile`](jenkins/Jenkinsfile) | `Jenkinsfile` (repo root) |

All templates auto-detect AI reachability: if `GROQ_API_KEY` is set as a secret/variable, `--ai-enhance` is added to the scan automatically. No key = scan still works, just without AI.

The testbed repos are forkable — fork one, push, and see REACHABLE scan results immediately.

---

## Release Verification

Every release is signed and checksummed. The installer verifies both automatically.

**SHA-256** — verified on every install. Mismatch aborts immediately.

**Cosign** — verified if `cosign` is installed. Keyless OIDC signatures via [Sigstore](https://sigstore.dev), tied to the GitHub Actions workflow that built the wheel.

Checksums and signature bundles for all releases are in `wheels/v<version>/`.

---

## Enzo — AI-Powered Security Intelligence (Experimental)

Enzo is REACHABLE's AI engine. It adds two capabilities on top of the core scan:

**AI Remediation** — Generates, validates, and commits security patches automatically. Each patch is tested in an isolated git worktree (syntax check, build, exploit test, rescan) before touching your code. Supports local models (Ollama — fully private) and cloud APIs (Groq, Claude).

**AI Reachability** — Refines the call graph's reachability verdicts using AI-powered analysis. The call graph determines if a *function* is reachable; the AI determines if the *variable* flowing into it is actually attacker-controlled. This reduces false positives where the code pattern matches but the input is a constant, config value, or validated data.

```bash
# Setup (one-time)
reachctl enzo setup                    # pulls model or configures API key
reachctl enzo doctor                   # health check

# Remediation
reachctl enzo scan ~/src/myapp         # show fixable findings
reachctl enzo run ~/src/myapp          # fix all (local model)
reachctl enzo run ~/src/myapp --mode cloud --provider groq  # cloud model

# AI reachability
reachctl enzo analyze ~/src/myapp --type cwe    # refine CWE verdicts
reachctl enzo analyze ~/src/myapp --deep        # full analysis
```

Enzo is experimental in this release. Results are written to the scan database and reflected in the dashboard with AI verification badges. Source code is never sent to cloud APIs unless you explicitly opt in.

---

## Roadmap

Active development. Here's where we're headed:

- **Enzo GA** — Production-ready AI remediation and reachability. Batch mode (`--ai-enhance` flag on scan), invocation pattern detection, secret loader tracing.
- **RADR** — Runtime Application Detection & Response. Lightweight agent that monitors running workloads and correlates runtime behavior with static scan findings.
- **Additional languages and build systems** — Expanding reachability analysis to more ecosystems.
- **Global intelligence cache** — Cross-scan knowledge graph that accelerates repeat scans and shares anonymized threat signals across deployments.
- **Multi-tenant SaaS dashboard** — Centralized visibility across teams, repos, and environments. Role-based access, trend analytics, and policy enforcement.

---

## Note

If `reachctl` is not found after install, add it to your PATH:

```bash
export PATH="$HOME/.reachable/venv/bin:$PATH"
```

Add to `~/.zshrc` or `~/.bashrc` to make it permanent.

---

## Support

Email: info@sthenosec.com

---

© 2026 Sthenos Security. All rights reserved.
