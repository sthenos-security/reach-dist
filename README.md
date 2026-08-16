# REACHABLE by Sthenos Security

Risk Exposure Validation for the AI era. REACHABLE combines deterministic validation, bounded AI reasoning, and agentic remediation to reduce exploitable risk first. One command, full interactive dashboard, about 90 seconds.

## Quick Start

```bash
# Install — run this from your repo root
curl -fsSL https://sthenosec.com/download/install.sh | bash

# Open a new shell (installer writes PATH to your shell rc automatically)
# or source ~/.zshrc / ~/.bashrc once in the current shell

# Scan
reachctl scan /path/to/your/repo
```

That's it. When the scan finishes, open the dashboard link printed in the terminal — or run `reachctl dashboard --open`.

**One install mode.** That single command installs the `reachctl` scanner *and*
the continuous surface: the local daemon, coding-agent hooks, the MCP server,
and the generated skills/rules. The skills loop is the product, so the component
that delivers it is not an add-on. CI runners opt out with
[`--no-vibe`](#ci-runners-and-other-ephemeral-hosts). The installer always
prints which surface it installed and why.

The public installer bootstrap verifies the signed release manifest, checks the
downloaded installer SHA-256, verifies the installer with Sigstore/cosign, and
only then runs the installer. The installer then verifies the wheel, dependency
constraints, and signed release artifacts before installing.

**Requirements:** Python 3.11+, `curl`, `python3`, `cosign`, and either Linux (x86_64/ARM64) or macOS (Apple Silicon/Intel).

### What the default install does

```bash
curl -fsSL https://sthenosec.com/download/install.sh | bash
```

- verifies the signed release manifest and installer before execution
- installs the main `reachable` wheel
- verifies wheel checksums, cosign bundles, and hash-pinned dependencies
- bootstraps external tools automatically
- starts the local daemon
- wires supported local coding agents in the current repo (hooks, MCP, skills)
- does not start a baseline scan unless you pass `--baseline`

If you are testing locally from the `reach-dist` checkout:

```bash
./install.sh
```

Useful public installer variants:

```bash
curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --agent codex
curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --agent cursor
curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --repo /path/to/repo
curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --baseline
```

Use `--baseline` only when you want install to run the first baseline scan and
build the initial DB-backed skill/rule bundle. The `--no-baseline`,
`--no-auto-vibe`, and `--skip-vibe-baseline` aliases still work as
compatibility no-ops because scan startup is now explicit. **None of those three
turn off the continuous surface** — only `--no-vibe` does that.

`--vibe` and `--vibe-coding` are still accepted and still install the full
surface. They are now redundant with the default, and every published agent
plugin sends `--vibe`, so they will keep working.

### CI runners and other ephemeral hosts

```bash
curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --no-vibe
```

`--no-vibe` (long form `--no-vibe-coding`) installs the scanner alone: no
daemon, no agent hooks, no MCP server, no generated skills. It exists for one
host type — CI runners and other ephemeral, non-interactive machines. A pipeline
is single-shot, usually containerised, and has nothing to supervise a
filesystem-watching daemon, so starting one there is waste at best and a hang
risk at worst. **Do not use it on a developer machine:** it removes the loop you
installed REACHABLE for. A `--no-vibe` install still has the full scanner and
`reachctl remediate`; only `reachctl vibe *`, the MCP tools, and the live
dashboard view are absent.

`--no-vibe` cannot be combined with `--vibe`, `--vibe-coding`, `--agent`, or
`--baseline` — those ask for the surface it removes. The installer exits 2 with
both flag names rather than picking a winner.

The public `https://sthenosec.com/download/install.sh` bootstrap detects
`GITHUB_ACTIONS`, `GITLAB_CI`, and `CI`, and installs the scanner alone on those
hosts so that pipelines pinned to a flagless `install.sh` do not silently gain a
daemon. It prints what it detected, and `--vibe` overrides it. That detection
lives in the bootstrap only — `install.sh` itself never reads the environment to
decide the surface, so there is exactly one place that can make this call. Both
paths always print the resolved surface and the reason for it.

After install:

```bash
reachctl vibe ui                       # open the global dashboard
reachctl vibe status                   # show daemon + all known workspaces
reachctl vibe status --repo /path/to/repo
reachctl vibe stats --repo /path/to/repo
reachctl remediate --repo /path/to/repo --agent codex --all
reachctl remediate --repo /path/to/repo --agent codex --all --branch-name reach-vibe-demo
ps -ef | grep '[r]each_agent _daemon'  # low-level daemon check
```

If explicitly requested, the baseline scan and skill synthesis do not modify
product source code. They write scanner truth into `repo.db`, update
`.reachable/ai-rules/`, and install the generated rules into each wired agent's
own guidance files (`AGENTS.md`, `CLAUDE.md`, `.claude/skills/`,
`.cursor/rules/`). The coding agent picks those up on its next turn, the way it
reads any of its rule files.

Applying them to code is a separate, explicit step. **Nothing starts a
remediation run on your behalf** — not the daemon, not a hook, not the MCP
server. A run only begins when you invoke `reachctl remediate` (or
`reachctl scan --remediate`). For reviewable code changes, pass `--branch-name`;
neither the installer nor the daemon silently creates a branch or rewrites the
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

REACHABLE follows one high-level AI-assisted risk exposure reduction flow: inventory, discovery, reachability, exposure validation, and remediation. The goal is simple: reduce exploitable risk first, keep defended paths out of the urgent queue, and produce evidence teams can trust.

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

**Why OpenRouter?** One key can access many supported models through one gateway. REACHABLE uses the configured, benchmark-qualified model for each AI lane; model defaults are changed only after task-specific qualification.

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

An upgrade resolves the surface the same way a fresh install does, so add
`--no-vibe` when upgrading a CI runner and `--vibe` when upgrading a developer
machine that a wrapper might read as CI. The installer prints the upgrade
command that reproduces the surface it just installed.

Run `./install.sh --help` for the full option list.

### Candidate bundle testing

Candidate and alpha installers can be tested without resolving production
`latest.json` by pointing the installer at an explicit signed artifact source:

```bash
# Local candidate artifact directory
REACHABLE_DIST_ROOT=/path/to/reachable-candidate-dist ./install.sh --clean

# Candidate artifact directory served over HTTP(S)
curl -fsSL https://sthenosec.com/download/install.sh \
  | REACHABLE_DIST_BASE_URL=https://example.test/reachable-candidate-dist bash -s -- --clean
```

Use `--version <ver>` when the candidate directory does not include
`latest.json`. The candidate artifact source must contain the selected
`reachable-<version>-<python-tag>-<python-tag>-<platform>.whl`,
`checksums.sha256`, the wheel `.cosign.bundle`, and hash-pinned
`constraints.txt`. Linux candidate bundles may also include
`vendor-<python-tag>-<platform>.tar.gz` plus its `.cosign.bundle`; if present,
the installer verifies both checksum and signature before use.

---

## CI/CD

Fork one of these repos and your pipeline runs REACHABLE automatically:

| Platform | Repo |
|---|---|
| GitHub Actions | [reach-testbed-github](https://github.com/sthenos-security/reach-testbed-github) |
| GitLab CI | [reach-testbed-gitlab](https://gitlab.com/sthenos-security-public/reach-testbed-gitlab) |
| Jenkins | [`jenkins/Jenkinsfile`](jenkins/Jenkinsfile) in this repo |

AI runs automatically if `OPENROUTER_API_KEY`, `GROQ_API_KEY`, `ANTHROPIC_API_KEY`, or `OPENAI_API_KEY` is set as a repo secret.

Install on a runner with `--no-vibe` — a pipeline is ephemeral and single-shot
and has no supervisor for a background daemon:

```bash
curl -fsSL https://sthenosec.com/download/install.sh | bash -s -- --no-vibe
```

The public bootstrap also detects `GITHUB_ACTIONS`, `GITLAB_CI`, and `CI` and
installs the scanner alone there even without the flag, printing what it
detected. Pass the flag anyway if your pipeline pins the installer asset
directly from the GitHub release, since that path bypasses the bootstrap.

For CI mode with threshold gating: `reachctl scan /path --ci --fail-on high`

For CI remediation demos, run `reachctl scan . --ci`, generate a bundle with
`reachctl remediate --workspace . --agent opencode --all`, pass
`.reachable/remediation-bundle/prompt.md` to the selected coding-agent action,
then rescan the `reachable-remediate-<run-id>` branch and require
`reachctl audit --scan-path "$REACHABLE_PROOF_SCAN_DIR" --summary` plus
`reachctl integrity --scan-path "$REACHABLE_PROOF_SCAN_DIR"` to pass.
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

Every release is signed with [Sigstore](https://sigstore.dev) cosign and
checksummed with SHA-256. The default `https://sthenosec.com/download/install.sh`
path verifies release provenance automatically:

1. Resolve `https://sthenosec.com/download/manifest.json`.
2. Download and cosign-verify `reachable-release-manifest.json`.
3. Download `install.sh`.
4. Check `install.sh` against the SHA-256 recorded in the signed manifest.
5. Cosign-verify `install.sh`.
6. Run the installer only after those checks pass.
7. Let the installer verify the wheel, constraints, vendor archive, checksums,
   and cosign bundles before installation.

The installer fails closed on missing signatures, checksum mismatches, wrong
issuer/identity, or missing release metadata. Manual verification remains
available for air-gapped review, but it is not required for the standard install
path.

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
