# REACHABLE by Sthenos Security

AI-powered application security scanner. REACHABLE combines static analysis, call-graph reachability, and AI agents to tell you which vulnerabilities are actually exploitable — and which ones are noise. One command, full interactive dashboard, 90 seconds.

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash

# Add to PATH (add this line to your ~/.zshrc or ~/.bashrc)
export PATH="$HOME/.reachable/venv/bin:$PATH"

# Set up tools and credentials
reachctl doctor

# Scan
reachctl scan /path/to/your/repo
```

That's it. The dashboard opens automatically when the scan finishes.

**Requirements:** Python 3.11+ and either Linux (x86_64/ARM64) or macOS (Apple Silicon/Intel).

---

## What It Finds

REACHABLE runs multiple scanners in one pass and delivers results through an interactive HTML dashboard.

**Vulnerabilities** — CVEs in your dependencies, with call-graph reachability. CWE code weaknesses (injection, auth flaws, crypto misuse) with source-level tracing. Hardcoded secrets and API keys. Application misconfigurations.

**Supply Chain** — Malware detection with behavioral sandbox analysis. Package health scoring. Typosquatting and dependency confusion detection.

**AI/LLM Security** — OWASP LLM Top 10 coverage. AI attack surface mapping across your codebase.

**Data Protection** — PII leakage and data exposure via taint analysis.

**Compliance** — Automated mapping to FedRAMP, CMMC 2.0, NIST 800-53, SOC2, and PCI-DSS.

---

## How Reachability Works

Most scanners tell you a vulnerability exists. REACHABLE tells you if it matters.

Static call graphs (built with tree-sitter — no JVM or external toolchain required) trace from HTTP entrypoints through your call chain to each finding. Functions not reachable from any entrypoint are marked NOT_REACHABLE, cutting noise by 30-40%.

Supported languages and frameworks for entrypoint detection and dead code analysis:

| Language | Frameworks |
|----------|-----------|
| **Python** | Flask, FastAPI, Django (FBV, CBV, DRF ViewSets), Pydantic |
| **JavaScript / TypeScript** | Express, Fastify, NestJS, React, Hono |
| **Go** | Echo, net/http, Gin |
| **Java** | Spring Boot |

All languages get CVE, secrets, malware, supply chain, and AI/LLM analysis regardless of call-graph support.

---

## AI-Powered Analysis

Call graphs tell you *if* a function is reachable. AI tells you *if it's exploitable*.

REACHABLE's AI engine (Enzo) reads the actual code surrounding each finding — the variables, the control flow, the data sources — and determines whether the vulnerability is a real threat or a false positive. A SQL injection in a function called from an HTTP route is reachable, but if the variable is a hardcoded constant, it's noise. AI makes this distinction automatically.

Three layers of AI analysis, each building on the last:

**AI Taint Verification** — For every REACHABLE finding, AI reads the code and answers: "Is the variable flowing into this vulnerability actually attacker-controlled?" Eliminates false positives that static analysis alone can't catch.

**AI Discovery** (`--deep-ai-analysis`) — A second independent scan pass powered by LLMs. Finds logic flaws, auth bypasses, and business logic issues that pattern-matching scanners miss entirely. Results tagged with a purple `Deep` badge in the dashboard.

**AI Remediation** (`reachctl fix`) — Generates, validates, and commits security patches. Each fix is tested in an isolated git worktree before touching your code. Currently in beta for Team and Enterprise accounts.

### Set up an AI provider

Set one API key and AI runs automatically on every scan:

```bash
reachctl doctor set openrouter-api-key    # recommended — openrouter.ai/keys
```

**Why OpenRouter?** One key, 300+ models, ~$0.001 per finding. REACHABLE routes each task to the best model automatically.

**Other providers:** `anthropic-api-key` (Claude — highest accuracy, ~$0.003/finding), `groq-api-key` (Groq — fastest, ~$0.0004/finding), `openai-api-key` (GPT-4o — ~$0.002/finding). For fully local / air-gapped setups, REACHABLE connects to Ollama or any OpenAI-compatible endpoint — run `reachctl primer` for setup instructions.

Without a key configured, REACHABLE still runs all scanners and call graphs — you get full detection and reachability, just without the AI verification layer. No code leaves your machine unless an AI key is set.

> **Data disclosure:** AI sends code snippets surrounding each finding (typically 10-30 lines) and finding metadata to the configured provider. Full source files are never sent. Use `--no-ai` for fully local scans even with a key configured.

---

## REACHABLE Cloud (Coming Soon)

REACHABLE Cloud is a hosted SaaS platform with team management, multi-repo dashboards, trend analytics, and policy enforcement. Currently in private beta — contact **info@sthenosec.com** for early access.

Plans: **Free** (single user, public repos), **Team**, and **Enterprise**.

---

## Upgrade

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --update
```

Use `--clean` when upgrading from a beta release to avoid database compatibility issues. Other installer options: `--version <ver>` to pin a specific version, `--wheel <path>` for local installs, `--list` to see available releases.

---

## CI/CD

Fork one of these repos and your pipeline runs REACHABLE automatically:

| Platform | Repo |
|---|---|
| GitHub Actions | [reach-testbed-github](https://github.com/sthenos-security/reach-testbed-github) |
| GitLab CI | [reach-testbed-gitlab](https://gitlab.com/sthenos-security/sthenos-security) |
| Jenkins | [`jenkins/Jenkinsfile`](jenkins/Jenkinsfile) in this repo |

AI runs automatically if `OPENROUTER_API_KEY`, `GROQ_API_KEY`, `ANTHROPIC_API_KEY`, or `OPENAI_API_KEY` is set as a repo secret.

For CI mode with threshold gating: `reachctl scan /path --ci --fail-on high`

---

## Going Further

For everything beyond the basics — AI remediation (`reachctl fix`), supply chain detonation sandboxes, air-gapped / local AI with Ollama, CI/CD integration, scan options, and more — run:

```bash
reachctl primer
```

Primer is a full interactive command reference built into the CLI. It covers every feature, flag, and configuration option with examples.

---

## Release Verification

Every release is signed with [Sigstore](https://sigstore.dev) cosign and checksummed with SHA-256. The installer verifies both automatically.

---

## Roadmap

REACHABLE is under active development. Coming next: AI-powered remediation GA, REACHABLE Cloud (SaaS) with team management and trend analytics, a runtime eBPF agent (RADR), expanded language support (Ruby, Rust, C/C++), and CNAPP integration for Wiz, Orca, and Prisma.

---

False positive? Email **fp@sthenosec.com**. General support: **info@sthenosec.com**.

See [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES) for dependencies and licenses.

© 2026 Sthenos Security. All rights reserved.
