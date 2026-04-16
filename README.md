# REACHABLE by Sthenos Security

Powered by AI agents, REACHABLE performs deep code reachability analysis, automated triage, and remediation assistance. As AI-driven threats grow more sophisticated, defenders need equally advanced tools. Know exactly which vulnerabilities are exploitable — and which ones are noise.

One command. Seven signal types. AI-verified results. Full interactive dashboard in 90 seconds.

---

## What You Get

REACHABLE performs multi-signal reachability analysis across your entire application stack and delivers results through an interactive, offline HTML dashboard.

**Security Analysis**
- **CVE / SBOM** — Dependency vulnerabilities with reachability analysis. Know which CVEs your code can actually reach.
- **CWE** — Code-level weaknesses (injection, auth flaws, crypto misuse) with source-level tracing
- **Secrets** — Hardcoded credentials, API keys, and tokens detected by Gitleaks and Semgrep, with reachability context — is the secret actually used?
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

## Supported Languages & Frameworks

Full analysis — CVE reachability, CWE, secrets, malware, supply chain, AI/LLM, DLP — works across these languages and frameworks.

| Language | Frameworks with Entrypoint + Dead Code Detection |
|----------|--------------------------------------------------|
| **Python** | Flask, FastAPI, Django (FBV, CBV, DRF ViewSets, `@api_view`, `@action`, `router.register()`), Pydantic |
| **JavaScript / TypeScript** | Express, Fastify (routes, plugins, `fastify.register()`), NestJS (`@Controller`, `@Get`/`@Post`, `@Injectable`, AppModule resolution), React (JSX component mounting) |
| **Go** | Echo (`e.GET`, `e.Group`), net/http, Gin |
| **Java** | Spring Boot (`@RestController`, `@GetMapping`, `@PostMapping`, `@RequestMapping`) |

Reachability analysis uses static call graphs (tree-sitter, no JVM or external toolchain required) to trace from HTTP entrypoints through the call chain to each finding. Functions not reachable from any entrypoint are marked NOT_REACHABLE — cutting noise by 30–40%.

Additional languages and frameworks are on the [roadmap](#roadmap).

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
| `--version`, `-v` | Install a specific version (e.g., `1.0.0-rc0`) |
| `--wheel`, `-w` | Install from a local wheel file |
| `--list`, `-l` | List available releases |

### Upgrade

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --update
```

> **Upgrade Notice:** Use `--clean` when upgrading from a beta release to avoid database compatibility issues.

---

## Getting Started

### 1. Add to PATH

```bash
export PATH="$HOME/.reachable/venv/bin:$PATH"
```

Add to your `~/.zshrc` or `~/.bashrc` to make it permanent.

### 2. First Run — reachctl doctor

`doctor` is the single entry point for everything: tool installation, credential setup, AI provider configuration, and system health checks.

```bash
reachctl doctor
```

On first run, doctor installs missing tools automatically (syft, grype, semgrep, guarddog, gitleaks) and walks you through credential setup. In CI/CD, use `reachctl doctor --ci` to read from environment variables without prompts.

Verify after doctor completes:

```bash
reachctl selftest
```

### 3. Set Up an AI Provider (Recommended)

Set one API key and every scan gets AI-verified results automatically:

```bash
# Recommended — single key, 300+ models, per-task routing
reachctl doctor set openrouter-api-key    # openrouter.ai/keys

# Or a specific provider:
reachctl doctor set anthropic-api-key     # Claude (highest accuracy)
reachctl doctor set groq-api-key          # Groq (fast, low cost)
reachctl doctor set openai-api-key        # OpenAI GPT-4o
```

The startup banner confirms which provider is active. Use `reachctl doctor status` to see all configured credentials.

### 4. Scan

```bash
reachctl scan /path/to/your/repo
```

Dashboard opens automatically.

### Scan Options

| Flag | Effect |
|------|--------|
| `--verbose` | Detailed output with per-scanner progress |
| `--no-dlp` | Skip DLP/PII analysis |
| `--ci --fail-on high` | CI mode with threshold gating |
| `--no-ai` | Skip AI taint oracle even if a key is set |
| `--deep-ai-analysis` | AI source discovery pass (finds issues pattern scanners miss) |

### AI Providers

| Provider | RPM | TPM | $/finding (approx) |
|----------|-----|-----|-------------------|
| **OpenRouter** (recommended) | 200 | 200K | ~$0.001 |
| **Claude** | 50–1,000 | 40K–450K | ~$0.003 |
| **Groq** | 120 | 100K | ~$0.0004 |
| **OpenAI** | 120+ | 200K+ | ~$0.002 |
| **Local (Ollama)** | ∞ | ∞ | free |

> **AI Data Disclosure:** When AI runs with a cloud provider, REACHABLE sends code snippets surrounding each finding (typically 10–30 lines) and finding metadata. Full source files are never sent. Without a configured key, no source code leaves your machine. Use `--no-ai` for fully local scans.

### Reference

```bash
reachctl primer       # Full interactive command reference
reachctl --help       # Quick overview
```

---

## CI/CD Integration

Ready-to-use CI/CD configurations — fork the testbed repo for your platform:

| Platform | Repo | What you get |
|---|---|---|
| GitHub Actions | [reach-testbed-github](https://github.com/sthenos-security/reach-testbed-github) | Fork, push, scan runs automatically |
| GitLab CI | [reach-testbed-gitlab](https://gitlab.com/sthenos-security/reach-testbed-gitlab) | Fork, push, scan runs automatically |

Both repos contain a working REACHABLE scan pipeline with install, scan, dashboard artifact upload, and SARIF reporting. AI reachability runs automatically if `OPENROUTER_API_KEY`, `GROQ_API_KEY`, `ANTHROPIC_API_KEY`, or `OPENAI_API_KEY` is set as a repo secret.

For Jenkins, see the [`jenkins/Jenkinsfile`](jenkins/Jenkinsfile) in this repo — drop it into your repo root and create a Pipeline job.

---

## Supply Chain Detonation (Linux)

Every pip and npm package is installed in an isolated sandbox before it reaches your environment. On macOS, this runs locally via Colima/Docker (`reachctl sandbox --init`). On Linux CI/CD runners, we provide a dedicated Firecracker detonation host — KVM-isolated microVMs with hardware-level separation.

### Quick Start

```bash
# 1. On the detonation host (bare-metal or nested-virt VM):
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/detonation/setup-detonation-host.sh | sudo bash

# 2. On your CI runner / dev machine:
reachctl sandbox --remote <detonation-host-ip>

# 3. Scan with remote detonation:
reachctl scan /path/to/repo --sandbox-mode remote
```

### What's Included

| File | Description |
|------|-------------|
| [`detonation/setup-detonation-host.sh`](detonation/setup-detonation-host.sh) | One-command Firecracker host setup (installs Firecracker, creates restricted SSH user, generates keypair, builds rootfs) |
| [`detonation/RUNBOOK.md`](detonation/RUNBOOK.md) | Full operational runbook: architecture, prerequisites, CI/CD config, troubleshooting, security model, teardown |

For CI/CD workflows with remote detonation enabled, see the testbed repos:
- [reach-testbed-github](https://github.com/sthenos-security/reach-testbed-github) — GitHub Actions with `--sandbox-mode remote`
- [reach-testbed-gitlab](https://gitlab.com/sthenos-security/reach-testbed-gitlab) — GitLab CI with `--sandbox-mode remote`

### How It Works

1. **Batch install** — all packages in one Firecracker microVM (~60s)
2. **If clean** — done (zero overhead for safe projects)
3. **If something fires** — binary search (bisect) isolates the malicious package in ~log₂(N) runs
4. **Detection signals**: credential theft (honeypot files), network exfiltration (blocked), `.pth` auto-execution, persistence (crontab/bashrc/systemd), obfuscated payloads (base64/exec/eval)

### Security Model

SSH transport with `ForceCommand` — the `detonation` user has no shell access; only the detonation handler binary runs. Host key pinning (`StrictHostKeyChecking=yes`) and machine-id verification detect host replacement or MITM. Firecracker uses KVM hardware virtualization — a 3+ exploit chain is required to escape the VM.

See the full [Runbook](detonation/RUNBOOK.md) for details.

---

## Release Verification

Every release is signed and checksummed. The installer verifies both automatically.

**SHA-256** — verified on every install. Mismatch aborts immediately.

**Cosign** — verified if `cosign` is installed. Keyless OIDC signatures via [Sigstore](https://sigstore.dev), tied to the GitHub Actions workflow that built the wheel.

Checksums and signature bundles are attached to each [GitHub Release](https://github.com/sthenos-security/reach-dist/releases).

List available releases: `./install.sh --list`

---

## Enzo AI Engine

Enzo adds AI-powered capabilities on top of the core scan. Both passes are optional — the scan is complete without them.

### 1. AI Reachability Analysis

AI goes one level deeper and determines whether the *variable* flowing into the vulnerable function is actually exploitable.

A SQL injection in a function called from an HTTP route is reachable — but if the variable is a hardcoded constant, it's a false positive. AI reads your code and makes this distinction for CWE, secrets, DLP, and AI/LLM findings.

```bash
# Set a key — AI runs automatically on the next scan
reachctl doctor set openrouter-api-key    # recommended
reachctl doctor set anthropic-api-key     # Claude (highest accuracy)
reachctl doctor set groq-api-key          # Groq (fast, cheap)

reachctl scan ~/src/myapp                 # AI runs automatically
reachctl scan ~/src/myapp --deep-ai-analysis  # + AI source discovery pass
reachctl scan ~/src/myapp --no-ai         # skip AI even though key is set

# Standalone analysis after a scan:
reachctl analyze ~/src/myapp --provider openrouter
reachctl analyze ~/src/myapp --mode local  # fully private, Ollama
```

Results appear in the scan log and as verification badges in the dashboard.

### 2. AI Remediation (Beta — Cloud Team/Enterprise)

> **Beta Feature:** AI remediation is available to Cloud Team and Enterprise accounts. Contact info@sthenosec.com for access.

Automatically generates, validates, and commits security patches. Each fix is tested in an isolated git worktree before touching your code:

1. Patch applies cleanly (syntax + build)
2. Exploit test verifies the vulnerability is resolved
3. Rescan confirms the finding is gone
4. Commit only if all checks pass

```bash
reachctl fix --list                       # show fixable findings
reachctl fix --all --dry-run              # preview patches without applying
reachctl fix --all                        # fix all findings
reachctl fix --id 07d2d96a               # fix one specific finding
```

Supports code patches (CWE), dependency upgrades (CVE), config changes, and secret rotation.

### 3. Bring Your Own Model (Enterprise / Air-Gapped)

For organizations that must keep code on-premises, REACHABLE connects to any Ollama or OpenAI-compatible model endpoint.

```bash
# Local machine
reachctl enzo setup                       # pull best model for your hardware

# Custom endpoint (shared GPU server, Kubernetes)
export OLLAMA_HOST=http://gpu-box.internal:11434
reachctl fix --all --mode local
```

Or configure per-repo in `.reachable.yml`:

```yaml
enzo:
  mode: local
  local_endpoint: http://gpu-box.internal:11434
  local_model: qwen2.5-coder:32b
```

---

## Roadmap

Active development. Here's where we're headed:

- **AI Discovery (Beta)** — LLM-powered vulnerability discovery runs alongside traditional scanners as a second independent pass. Finds logic flaws, auth bypasses, and business logic issues that pattern-matching tools miss. Results tagged with purple `Deep` badge in the dashboard.
- **Zero False Positive Pipeline** — Completing the canonical AppSec workflow: AI discovery → static FP elimination → AI reachability verification → dynamic sandbox confirmation → idiomatic patch generation → test validation → PR. Each stage further filters noise so developers only see confirmed, ready-to-merge fixes.
- **AI-Powered Remediation GA** — `reachctl fix` generates, validates, and commits security patches. Currently in beta for Cloud Team and Enterprise accounts. Targeting GA in the next release.
- **REACHABLE Cloud (SaaS)** — Hosted dashboard with team management, multi-repo views, trend analytics, and policy enforcement. Currently in private beta — contact info@sthenosec.com for early access.
- **RADR Runtime Agent** — Lightweight eBPF agent that correlates runtime behavior with static scan findings. Eliminates the last category of unknown reachability.
- **Additional Languages** — Expanding reachability analysis to Ruby, Rust, C/C++, and additional frameworks.
- **CNAPP Integration** — Pre-computed reachability metadata as a build artifact consumed by Wiz, Orca, Prisma, and other CNAPP platforms to enrich runtime attack paths with code-level context.

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
