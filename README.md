# REACHABLE by Sthenos Security

Powered by AI agents, REACHABLE performs deep code reachability analysis, automated triage, and remediation assistance. As AI-driven threats grow more sophisticated, defenders need equally advanced tools. Know exactly which vulnerabilities are exploitable — and which ones are noise.

One command. Seven signal types. AI-verified results. Full interactive dashboard in 90 seconds.

---

## What's New in v1.0.0-beta35

- **AI reachability analysis** — Runs automatically when a provider key is configured. Use `--no-ai-taint` to skip, `--deep-ai` for high-cost deep mode (also reviews NOT_REACHABLE findings).
- **Tree-sitter call graph** — Go, JS/TS, and Java call graph parsing via tree-sitter (fast, no JVM required)
- **AI remediation** — Automatically generates and validates security patches
- **Enhanced reachability test coverage** — Expanded validation across all signal types and languages
- **Improved build & release** — Added Linux tests, reduced wheel sizes

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
| `--version`, `-v` | Install a specific version (e.g., `1.0.0b35`) |
| `--wheel`, `-w` | Install from a local wheel file |
| `--list`, `-l` | List available releases |

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

### 2. First Run — Install Dependencies

The wheel contains only Python code. External tools are installed by `doctor` on first run:

```bash
reachctl doctor
```

Doctor runs a six-step system check and installs anything that’s missing:

```
REACHABLE SYSTEM CHECK
[1/4] System Resources    — OS, RAM, disk, GPU, Ollama status
[2/4] Required Tools      — syft, grype, semgrep, guarddog, sandbox (colima/docker)
[3/4] Git                 — version check and credential status
[4/5] Optional Enhancements — trufflehog, joern, ollama + local models
[5/5] Credentials         — GitHub token, MCP token, AI API keys (keychain or env)
[6/6] Enzo build tools    — mvn, gradle, go, cargo, node, bundle, composer
```

Missing build tools can be fixed with `reachctl enzo doctor --fix`.

On macOS, OS libraries come from Xcode Command Line Tools (pre-installed). On Linux, doctor uses `sudo apt-get` if available.

Verify after doctor completes:

```bash
reachctl selftest
```

### 3. Scan

```bash
reachctl scan /path/to/your/repo
```

Dashboard opens automatically.

### Scan Options

| Flag | Effect |
|------|--------|
| `--debug` | Verbose output with timestamps |
| `--no-dlp` | Skip DLP/PII analysis |
| `--ci --fail-on high` | CI mode with threshold gating |
| `--no-ai-taint` | Skip AI taint oracle even if a provider key is set |
| `--deep-ai` | AI taint on NOT_REACHABLE findings too (higher cost) |

### 4. AI Reachability (Automatic)

AI taint analysis runs automatically when a provider key is configured. Set one key and every scan gets AI verification:

```bash
export GROQ_API_KEY=gsk_...
reachctl scan /path/to/your/repo
```

Supported providers: Groq (`GROQ_API_KEY`), OpenAI (`OPENAI_API_KEY`), Anthropic (`ANTHROPIC_API_KEY`), or `reachctl auth login` for keychain storage.

The startup banner confirms which provider is active. The dashboard shows AI verification badges next to each finding. Use `--no-ai-taint` to skip AI even when a key is set. Use `--deep-ai` to also analyze NOT_REACHABLE findings (higher cost, opt-in).

> **AI Data Disclosure:** When AI taint runs with a cloud provider, REACHABLE sends code snippets surrounding each security finding (typically 10–30 lines) and finding metadata (file path, line number, finding type) to the selected LLM API for analysis. Full source files and your complete repository are never sent. Without a configured key, no source code leaves your machine. Your data is governed by your cloud LLM provider's terms of service and data retention policies. For fully private analysis with no external data transfer, use a local model via `reachctl enzo analyze --mode local`.

### 5. Authentication (Recommended)

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

All templates auto-detect AI reachability: if `GROQ_API_KEY` (or `OPENAI_API_KEY` / `ANTHROPIC_API_KEY`) is set as a secret/variable, AI taint runs automatically. No key = scan still works, just without AI.

The testbed repos are forkable — fork one, push, and see REACHABLE scan results immediately.

---

## Release Verification

Every release is signed and checksummed. The installer verifies both automatically.

**SHA-256** — verified on every install. Mismatch aborts immediately.

**Cosign** — verified if `cosign` is installed. Keyless OIDC signatures via [Sigstore](https://sigstore.dev), tied to the GitHub Actions workflow that built the wheel.

Checksums and signature bundles are attached to each [GitHub Release](https://github.com/sthenos-security/reach-dist/releases).

List available releases: `./install.sh --list`

---

## Enzo AI Engine (Experimental)

Enzo adds two AI-powered capabilities on top of the core scan. Both are optional — the scan is complete without them.

### 1. AI Reachability Analysis

AI goes one level deeper and determines whether the *variable* flowing into the vulnerable function is actually exploitable.

A SQL injection in a function called from an HTTP route is reachable — but if the variable is a hardcoded constant, it's a false positive. AI reads your code and makes this distinction for CWE, secrets, DLP, and AI/LLM findings.

```bash
# Cloud (zero setup — set one API key and go)
export GROQ_API_KEY=gsk_...                   # console.groq.com/keys (fast, cheap)
export OPENAI_API_KEY=sk-...                  # platform.openai.com/api-keys (GPT-4o)
export ANTHROPIC_API_KEY=sk-ant-...           # console.anthropic.com (highest quality)
reachctl scan ~/src/myapp                     # AI runs automatically, auto-detects key
reachctl scan ~/src/myapp --deep-ai           # also analyze NOT_REACHABLE (higher cost)
reachctl scan ~/src/myapp --no-ai-taint       # skip AI even though key is set

# Explicit provider (for standalone analyze or enzo run):
reachctl enzo analyze ~/src/myapp --mode cloud --provider groq
reachctl enzo analyze ~/src/myapp --mode cloud --provider openai
reachctl enzo analyze ~/src/myapp --mode cloud --provider claude

# Local (fully private — code never leaves your machine)
reachctl enzo setup                           # pull model (~20GB, one-time)
reachctl scan ~/src/myapp                     # auto-detects local model
```

Results appear in the scan log and as verification badges in the dashboard.

### 2. AI Remediation

Automatically generates, validates, and commits security patches. Each fix is tested in an isolated git worktree before touching your code:

1. Patch applies cleanly (syntax + build)
2. Exploit test verifies the vulnerability is resolved
3. Rescan confirms the finding is gone
4. Commit only if all checks pass

```bash
reachctl enzo scan ~/src/myapp                # show fixable findings
reachctl enzo run ~/src/myapp --dry-run       # preview patches without applying
reachctl enzo run ~/src/myapp                 # fix all findings
```

Supports code patches (CWE), dependency upgrades (CVE), config changes, and secret rotation. Works with local models (Ollama) or cloud APIs (Groq, OpenAI, Claude).

See `reachctl enzo --help` and `reachctl primer` for the full command reference.

### 3. Bring Your Own Model (Enterprise / Air-Gapped)

For organizations that must keep code on-premises, REACHABLE connects to any pre-existing Ollama or OpenAI-compatible model endpoint. You provide the running model; REACHABLE connects to it.

```bash
# Quick setup (local machine — auto-detect resources, pull best model)
reachctl enzo setup

# Custom endpoint (shared GPU server, Kubernetes, etc.)
export ENZO_LOCAL_ENDPOINT=http://gpu-box.internal:11434
export ENZO_LOCAL_MODEL=qwen2.5-coder:32b
reachctl enzo analyze ~/src/myapp --mode local
reachctl enzo run ~/src/myapp --mode local
```

Or configure per-repo in `.reachable.yml`:

```yaml
enzo:
  mode: local
  local_endpoint: http://gpu-box.internal:11434
  local_model: qwen2.5-coder:32b
```

The scan pipeline uses cloud providers by default for convenience (auto-detected from env/keychain). For local model analysis, use `reachctl enzo analyze --mode local` after scanning. Health check: `reachctl enzo doctor`.

---

## Roadmap

Active development. Here's where we're headed:

- **Enzo GA** — Production-ready AI reachability analysis (variable-level taint) and AI remediation (automated patching). Invocation pattern detection, dedicated AI/LLM and DLP prompts, `--deep-ai` mode.
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

---

> ⚠️ Results are risk-informed guidance based on available data sources and metadata; not a guarantee of security or compliance. Sthenos Security assumes no liability for actions taken based on these findings and does not share or expose your proprietary source code.
