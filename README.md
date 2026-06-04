# REACHABLE by Sthenos Security

Risk Exposure Validation for the AI era. REACHABLE inventories code and dependencies, discovers security signals, proves reachability, validates exposure, and drives remediation so teams can reduce exploitable risk first. One command, full interactive dashboard, about 90 seconds.

## Quick Start

```bash
# Install
curl -fsSL https://sthenosec.com/download/install.sh | bash

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
curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --vibe
```

That path:

- installs the main `reachable` wheel
- bootstraps external tools automatically
- runs bundled `reach-vibe` setup
- starts the local daemon
- runs the initial baseline scan and builds the DB-backed skill/rule bundle
- wires supported local coding agents in the current repo

If you are testing locally from the `reach-dist` checkout:

```bash
./install.sh --vibe
```

Useful public installer variants:

```bash
curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --vibe --agent codex
curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --vibe --agent cursor --no-baseline
curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --vibe --repo /path/to/repo
```

Use `--no-baseline` when you want to wire the daemon, agents, and MCP endpoint
without running the install-time baseline scan. The older
`--no-auto-vibe`/`--skip-vibe-baseline` aliases still work.

After install:

```bash
reachctl vibe ui                       # open the global dashboard
reachctl vibe status                   # show daemon + all known workspaces
reachctl vibe status --repo /path/to/repo
reachctl vibe stats --repo /path/to/repo
reachctl vibe remediate --repo /path/to/repo --branch-name reach-vibe-demo
reachctl remediate --repo /path/to/repo --agent codex --all
ps -ef | grep '[r]each_agent _daemon'  # low-level daemon check
```

The baseline scan and skill synthesis do not modify product source code. They
write scanner truth into `repo.db`, update `.reachable/ai-rules/`, and refresh
agent guidance. Those rules are used on the next hook/MCP/agent event or by an
explicit `reachctl vibe remediate` run. For reviewable code changes, pass
`--branch-name`; the installer does not silently create a branch or rewrite the
repo.

For CI or desktop agent orchestration, `reachctl remediate` writes
`.reachable/remediation-bundle/prompt.md`, `bundle.json`, `ai-rules/`, and
`remediation-prompt-audit.json`. Reachable owns scan truth, ranking, audit, and
the proof rescan; Codex, Claude Code, Cursor, OpenCode, Copilot, or another
configured coding agent owns the code edits.

Supported local agent config locations:

| Agent | Primary config |
|---|---|
| Codex | `$CODEX_HOME/config.toml` or `~/.codex/config.toml`; workspace hooks in `.codex/hooks.json`; rules in `AGENTS.md` |
| Claude Code | `.claude/settings.json`; MCP via `claude mcp add`; rules in `CLAUDE.md` and `.claude/skills/*/SKILL.md` |
| Cursor | `.cursor/mcp.json`, plus `~/.cursor/projects/<workspace>/mcps`; rules in `.cursor/rules/*.mdc` |
| OpenCode | workspace `opencode.json`; optional `$OPENCODE_CONFIG` or `~/.config/opencode/opencode.json` |
| Copilot | `.vscode/mcp.json` for GitHub/Copilot workflows |

Developer check:

```bash
python scripts/reach_agent_config_check.py --workspace /path/to/repo \
  --agents codex,claude,cursor,opencode --json
```

Node.js is not required just to install or run `reach-vibe`. Keep Node
available if the target repo itself uses Node/npm tooling.

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

**Vulnerabilities** — CVEs in your dependencies, with reachability analysis. CWE code weaknesses (injection, auth flaws, crypto misuse) with source-level tracing. Hardcoded secrets and API keys. Application misconfigurations.

**Supply Chain** — Malware detection with behavioral sandbox analysis. Package health scoring. Typosquatting and dependency confusion detection.

**AI/LLM Security** — OWASP LLM Top 10 coverage. AI attack surface mapping across your codebase.

**Data Protection** — PII leakage and data exposure analysis.

**Compliance** — Automated mapping to FedRAMP, CMMC 2.0, NIST 800-53, SOC2, and PCI-DSS.

---

## How It Works

REACHABLE follows one high-level risk exposure reduction flow: inventory, discovery, reachability, exposure validation, and remediation. The goal is simple: reduce exploitable risk first, keep defended paths out of the urgent queue, and produce evidence teams can trust.

<p align="center">
  <img src="docs/images/how-it-works.svg" alt="High-level REACHABLE workflow: inventory, discovery, reachability, exposure validation, and remediation" width="760"/>
</p>

### Validation workflow

REACHABLE inventories the codebase, discovers security signals across source and dependencies, proves which paths are reachable, then validates whether reachable exposure is attackable, defended, or still uncertain. This keeps attention on risk that can actually matter instead of raw alert volume.

| Language | Frameworks |
|----------|-----------|
| **Python** | Flask, FastAPI, Django (FBV, CBV, DRF ViewSets), Pyramid, Pydantic |
| **JavaScript / TypeScript** | Express, Fastify, NestJS, React, Hono, Sails.js |
| **Go** | Echo, Gin, net/http |
| **Java / Kotlin** | Spring Boot |

All languages get CVE, secrets, malware, supply chain, and AI/LLM analysis regardless of framework support.

### Remediation workflow

Remediation follows the validation result. REACHABLE prioritizes attackable exposure first, preserves defended paths as evidence, and hands fix work to the local or CI workflow with proof after rescan. In AI-DLC mode, validation feedback guides the next coding-agent pass before the next change ships.

Every decision is logged with enough metadata to support review, reporting, and governance evidence. Customer source code, prompt bodies, and private logs are not part of the public evidence export.

### Set up an AI provider

Set one API key and AI runs automatically on every scan:

```bash
reachctl doctor set openrouter-api-key    # recommended — openrouter.ai/keys
```

**Why OpenRouter?** One key, 300+ models, ~$0.001 per finding. REACHABLE routes each task to the best model automatically.

**Other providers:** `anthropic-api-key` (Claude — highest accuracy, ~$0.003/finding), `groq-api-key` (Groq — fastest, ~$0.0004/finding), `openai-api-key` (GPT-4o — ~$0.002/finding). For fully local / air-gapped setups, REACHABLE connects to Ollama or any OpenAI-compatible endpoint — run `reachctl primer` for setup instructions.

Without a key configured, REACHABLE still runs all scanners and reachability analysis. You get full detection, just without the AI validation layer. No code leaves your machine unless an AI key is set.

> **Data disclosure:** AI sends code snippets surrounding each finding (typically 10-30 lines) and finding metadata to the configured provider. Full source files are never sent. For fully local scans even with a key configured, disable the specific AI passes you do not want to run, such as `--no-ai-owasp`, `--no-ai-reachability`, `--no-ai-discovery`, `--no-ai-package-analysis`, and `--no-attack-prompt`.

---

## REACHABLE Cloud (Coming Soon)

REACHABLE Cloud is a hosted SaaS platform with team management, multi-repo dashboards, trend analytics, and policy enforcement. Currently in private beta — contact **info@sthenosec.com** for early access.

Plans: **Free** (single user, public repos), **Team**, and **Enterprise**.

---

## Upgrade

```bash
curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --update
```

Use `--clean` when upgrading from a beta release to avoid database compatibility issues. Other installer options: `--version <ver>` to pin a specific version, `--wheel <path>` for local installs, `--list` to see available releases.

---

## CI/CD

Fork one of these repos and your pipeline runs REACHABLE automatically:

| Platform | Repo |
|---|---|
| GitHub Actions | [reach-testbed-github](https://github.com/sthenos-security/reach-testbed-github) |
| GitLab CI | [reach-testbed-gitlab](https://gitlab.com/sthenos-security-public/reach-testbed-gitlab) |
| Jenkins | [`jenkins/Jenkinsfile`](jenkins/Jenkinsfile) in this repo |

AI runs automatically if `OPENROUTER_API_KEY`, `GROQ_API_KEY`, `ANTHROPIC_API_KEY`, or `OPENAI_API_KEY` is set as a repo secret.

For CI mode with threshold gating: `reachctl scan /path --ci --fail-on high`

For CI remediation demos, run `reachctl scan . --ci`, generate a bundle with
`reachctl remediate --workspace . --agent opencode --all`, pass
`.reachable/remediation-bundle/prompt.md` to the selected coding-agent action,
then rescan the `reachable-remediate-<run-id>` branch and require
`reachctl audit --latest --summary` plus `reachctl integrity --latest` to pass.
Set agent/provider secrets such as `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`,
`OPENROUTER_API_KEY`, `GITHUB_TOKEN`, and `MCP_GITHUB_TOKEN` as needed.

---

## Going Further

For everything beyond the basics — agentic remediation, supply chain validation, air-gapped / local AI with Ollama, CI/CD integration, scan options, and more — run:

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
