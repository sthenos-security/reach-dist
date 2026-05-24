# REACHABLE by Sthenos Security

Risk Exposure Validation for the AI era. REACHABLE combines static analysis, data flow graph (DFG) reachability, and focused AI reasoning to validate which findings are truly exploitable, which paths are already defended, and which results still need review. One command, full interactive dashboard, about 90 seconds.

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash

# Open a new shell (installer writes PATH to your shell rc automatically)
# or source ~/.zshrc / ~/.bashrc once in the current shell

# Scan
reachctl scan /path/to/your/repo
```

That's it. When the scan finishes, open the dashboard link printed in the terminal — or run `reachctl dashboard --open`.

**Requirements:** Python 3.11+ and either Linux (x86_64/ARM64) or macOS (Apple Silicon/Intel).

### Vibe-coding quick start

For local coding-agent protection, the first-cut install path is shell-first:

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --vibe
```

That path:

- installs the main `reachable` wheel
- bootstraps external tools automatically
- runs bundled `reach-vibe` setup
- wires supported local coding agents in the current repo

If you are testing locally from the `reach-dist` checkout:

```bash
./install.sh --vibe
```

Useful variants:

```bash
./install.sh --vibe --agent codex
./install.sh --vibe --agent cursor --no-auto-vibe
./install.sh --vibe --repo /path/to/repo
```

The npm / `npx` entrypoint is planned next, but it will be a thin wrapper over
this same installer path, not a separate installer implementation.

### Tokens and limited mode

First-run vibe-coding setup should not block on tokens.

Today the intended posture is:

- no-token mode still installs and works
- `reachctl doctor` remains the canonical way to add optional credentials later
- external tools are installed automatically by the installer

Optional credentials such as GitHub / MCP tokens and AI provider keys improve
coverage and AI-assisted behavior, but they are not required for the initial
shell-first install path.

---

## What It Finds

REACHABLE runs multiple scanners in one pass and delivers results through an interactive HTML dashboard.

**Vulnerabilities** — CVEs in your dependencies, with DFG reachability analysis. CWE code weaknesses (injection, auth flaws, crypto misuse) with source-level tracing. Hardcoded secrets and API keys. Application misconfigurations.

**Supply Chain** — Malware detection with behavioral sandbox analysis. Package health scoring. Typosquatting and dependency confusion detection.

**AI/LLM Security** — OWASP LLM Top 10 coverage. AI attack surface mapping across your codebase.

**Data Protection** — PII leakage and data exposure via taint analysis.

**Compliance** — Automated mapping to FedRAMP, CMMC 2.0, NIST 800-53, SOC2, and PCI-DSS.

---

## How It Works

Most scanners stop at discovery. REACHABLE goes beyond reachability to validate whether a live path is exploitable, defended, or still uncertain.

<p align="center">
  <img src="docs/images/how-it-works.svg" alt="Reachable architecture: deterministic pipeline with AI reasoning" width="680"/>
</p>

### Deterministic pipeline

Six scanners run in parallel (CVE, CWE, secrets, DLP, AI risk, malware), then a multi-pass classification engine proves which findings are actually reachable by an attacker. Import resolution, call graph analysis, taint tracking, and framework-aware classifiers eliminate 60–70% of noise deterministically, with zero AI cost and no data leaving your machine.

| Language | Frameworks |
|----------|-----------|
| **Python** | Flask, FastAPI, Django (FBV, CBV, DRF ViewSets), Pyramid, Pydantic |
| **JavaScript / TypeScript** | Express, Fastify, NestJS, React, Hono, Sails.js |
| **Go** | Echo, Gin, net/http |
| **Java / Kotlin** | Spring Boot |

All languages get CVE, secrets, malware, supply chain, and AI/LLM analysis regardless of framework support.

### AI reasoning engine

Findings that deterministic analysis cannot fully resolve are passed to a reasoning engine that orchestrates multiple AI agents. That layer helps validate whether a reachable path is actually exploitable, already defended, or still uncertain given its surrounding code context. Remediation generates fix guidance with code suggestions tailored to your framework.

Every AI decision is logged to a structured audit trail — model used, input context, output reasoning, confidence score, and cost. Deterministic verdicts always take precedence: AI cannot override a proven REACHABLE or NOT_REACHABLE classification.

AI features include taint verification, deep vulnerability discovery (`--deep-ai-analysis`), and automated remediation (`reachctl fix`, beta).

### Set up an AI provider

Set one API key and AI runs automatically on every scan:

```bash
reachctl doctor set openrouter-api-key    # recommended — openrouter.ai/keys
```

**Why OpenRouter?** One key, 300+ models, ~$0.001 per finding. REACHABLE routes each task to the best model automatically.

**Other providers:** `anthropic-api-key` (Claude — highest accuracy, ~$0.003/finding), `groq-api-key` (Groq — fastest, ~$0.0004/finding), `openai-api-key` (GPT-4o — ~$0.002/finding). For fully local / air-gapped setups, REACHABLE connects to Ollama or any OpenAI-compatible endpoint — run `reachctl primer` for setup instructions.

Without a key configured, REACHABLE still runs all scanners and DFG reachability. You get full detection, just without the AI validation layer. No code leaves your machine unless an AI key is set.

> **Data disclosure:** AI sends code snippets surrounding each finding (typically 10-30 lines) and finding metadata to the configured provider. Full source files are never sent. For fully local scans even with a key configured, disable the specific AI passes you do not want to run, such as `--no-ai-owasp`, `--no-ai-reachability`, `--no-ai-discovery`, `--no-ai-package-analysis`, and `--no-attack-prompt`.

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

REACHABLE is under active development. Coming next: AI-powered remediation GA, REACHABLE Cloud (SaaS) with team management and trend analytics, a runtime eBPF agent (RADR), expanded language support (Ruby, Rust, C/C++), and CNAPP integration.

---

## Contributors

Security review and attacker-minded feedback by **[Peter Levashov / SeveraDAO Security](https://severadao.ai/index.html)**.

Thanks to our beta testers for early feedback, bug reports, and real-world scan validation across production codebases.

---

Questions or false positive reports? Email **info@sthenosec.com**.

See [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES) for dependencies and licenses.

© 2026 Sthenos Security. All rights reserved.
