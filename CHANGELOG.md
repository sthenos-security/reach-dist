# REACHABLE Changelog

---

## [1.0.0-beta35] — AI Reachability GA

### AI Reachability (`--ai-enhance`)

- **Cloud-first** — `reachctl scan --ai-enhance` uses Groq or Claude API. Zero local setup — set one API key and go. Auto-detects key from env vars or system keychain.
- **Four-signal AI analysis** — CWE (taint), SECRET (loader), DLP (flow), AI/LLM (guardrails). CVE/MALWARE/CONFIG skipped by design — call graph is the gold standard for those.
- **AI/LLM security prompt** — Dedicated prompt for OWASP LLM findings. Detects user input flowing to LLM APIs without guardrails (prompt injection, jailbreak exposure).
- **DLP three-pass analysis** — DLP and AI/LLM findings from separate tables (`dlp_findings`, `ai_findings`) now analyzed alongside `findings`. Three adapters map different schemas to unified `EnzoFinding`.
- **Malware guard v2** — Files with malware findings are analyzed normally (not skipped). AI can confirm ATTACKER_CONTROLLED. Only demotion to SAFE is blocked (behavior overrides taint). Unblocked 119 CWE findings previously suppressed.
- **Plan/cost/time estimate** — Shows findings breakdown, estimated API calls, time, and cost before analysis starts.
- **User-friendly output** — Clean summary: confirmed exploitable, downgraded safe, per-signal breakdown. No internal noise (UNCERTAIN counts, malware guard skips).
- **Testbed validated** — 292 confirmed exploitable, 51 safe, 56.5% noise reduction. All AI verdicts verified against signal-matrix and invocation-patterns ground truth.

### Scan Pipeline

- **Semgrep exclude version stamp** — Per-repo `semgrep-exclude.txt` now re-seeds automatically when `EXCLUDE_DIRS` changes. Fixes stale exclusion lists from prior versions.
- **Provider-agnostic error handling** — Fatal error detection covers Groq, Claude, OpenAI, and generic HTTP auth failures (401/403). Rate limit and quota exhaustion abort gracefully.
- **`--include-unknown-secrets` removed** — Dead flag (UNKNOWN already in default analysis set). Simplified to two modes: default (REACHABLE + UNKNOWN) and `--deep` (adds NOT_REACHABLE).

### Documentation

- **AI signal filtering table** — Design doc §7: which signals AI analyzes and why, with detailed rationale for each.
- **Pre-release checklist** — `validate.py` required before every build. Known CG failures tracked.
- **Enzo section rewrite** — reach-dist README clearly separates AI Reachability Analysis vs AI Remediation.
- **Setup and provider tables** — `doctor --full` + `enzo setup` flow documented. Cloud vs local decision matrix.

### Known Issues

- **CG-JS-FP** — JavaScript call graph over-traces `require()` chains. `cwe_not_reachable.js` and `dead_code.js` incorrectly marked REACHABLE.
- **CG-PY-UNK** — Python `cwe_unknown.py` classified NOT_REACHABLE instead of UNKNOWN (conservative direction).
- **Rate limit handling** — Groq free tier rate-limits can cause slow scans (~20 min for 419 findings). Graceful abort partially implemented.

---

## [1.0.0-beta34] — AI-Enhanced Reachability

### Enzo AI Reachability (`enzo analyze`)

- **AI taint oracle** — Variable-level reachability refinement. Determines whether the variable at a sink is attacker-controlled (ATTACKER_CONTROLLED), safe (constant/config/validated), or uncertain.
- **Three-layer pipeline** — Call graph (function) + AI taint (variable) + AI invocation (execution pattern). `--deep` flag runs all three on every finding.
- **Dashboard AI badges** — Green "AI ✓" (confirmed), blue "AI ↓" (safe/demoted), red "AI ↑" (promoted by AI).
- **Malware guard** — Files flagged by malware scanner are auto-skipped by taint analysis. Behavior overrides taint.
- **Prompt caching** — SHA-256 prompt hash skips re-analysis of unchanged code.
- **Branch cleanup** (`enzo clean`) — Purge fix/batch branches. `--all` or `--dry-run`.

### Enzo Remediation Improvements

- **autopep8 indent repair** — Replaces heuristic indent fixer. Indent hallucinations 27→18, autopep8 fixed 25 issues.
- **Merge conflict auto-resolution** — 150 conflicts auto-resolved, 0 unresolved.
- **Clearer testgen logs** — Advisory exploit tests show ⚠ (not ✗) with explanation.
- **99% success rate** — 311/314 findings remediated on testbed.

### Schema

- **`findings` table** — Added `taint_verdict`, `taint_source`, `taint_confidence`, `taint_reasoning`, `reachability_source` columns.
- **`ai_reachability_audit` table** — Full verdict history for debugging (model, tokens, cost, duration, prompt hash).
- **Migration** — Existing databases auto-migrate via `ALTER TABLE ADD COLUMN`.

### Documentation

- **`ai-enhanced-reachability.md`** — Complete design doc: three layers, risk matrix, data flow, CLI, phases.
- **`enzo-validation-pipeline.md`** — Validation stage reference with blocking vs advisory.
- **Primer** — AI Reachability runbook, `--ai-enhance` scan flag.
- **Invocation patterns test suite** — 4 languages × 3 cases × 7 subtypes in reach-testbed.

---

## [1.0.0-beta33] — First Public Beta

REACHABLE 1.0.0-beta33 is the first public beta release with fully compiled, signed, multi-platform wheels. This release represents a complete rearchitecture from the internal alpha, with significant improvements across every layer.

### Platform

- **Cython-compiled wheels** — IP-protected `.so` binaries for all protected modules (correlation engine, call graph, malware detection, licensing, DLP, AI security, Enzo). Source code is not shipped.
- **12 wheels per release** — Python 3.11–3.14 × Linux x86_64, Linux ARM64, macOS universal2 (Intel + Apple Silicon)
- **Keyless cosign signing** — every wheel is signed via Sigstore OIDC tied to the GitHub Actions build, with SHA-256 checksums and a transparency log entry
- **One-line installer** — `curl | bash` with automatic platform detection, checksum verification, and optional cosign signature verification

### Scanning

- **Concurrent collectors** — all seven scanners (CVE/SBOM, Secrets, CWE, Malware, IaC, AI/LLM, DLP/PII) run concurrently in a single process. Typical scan: 60–90 seconds.
- **Multi-signal reachability** — call graph analysis determines whether CVEs, secrets, and CWE findings are actually reachable from application code. Three-state model: REACHABLE / NOT_REACHABLE / UNKNOWN.
- **Malware sandbox** — behavioral analysis via Docker containers. Static + dynamic detection with 4-counter metrics (confirmed/suspicious).
- **Package health scoring** — popularity, activity, and maintenance signals from npm/PyPI/GitHub. Dependency confusion and typosquatting detection.
- **AI/LLM security** — OWASP LLM Top 10 and MITRE ATLAS coverage with Agentic Security Index integration
- **DLP/PII taint analysis** — data exposure and privacy risk detection across source code

### Dashboard

- **Interactive HTML dashboard** — single-file, fully offline. Tabbed interface covering all seven signal types plus compliance, trends, and coverage.
- **Compliance framework mapping** — FedRAMP, CMMC 2.0, NIST 800-53, SOC2, PCI-DSS. GRC framework inferral from scan findings.
- **SARIF export** — integrates with GitHub Security tab, GitLab SAST, and any SARIF-compatible tool

### CLI

- **`reachctl scan`** — single command replaces the old multi-step pipeline. `--ci` mode for headless environments with structured exit codes.
- **`reachctl doctor`** — dependency installer and health checker for all scanning tools
- **`reachctl selftest`** — installation validator with `--unit`, `--integration`, and `--full` modes
- **`reachctl primer`** — built-in quick-start guide and command reference
- **`reachctl auth login`** — secure keychain-based token storage (GitHub, MCP)

### Enzo (Experimental)

- **AI-assisted remediation engine** — Automated patch generation, validation, and commit for CVE, CWE, and secrets findings. 99% success rate on testbed (311/314 findings remediated). Closed-loop validation: syntax check, build, exploit test, semgrep rescan.
- **AI reachability analysis** (`enzo analyze`) — Refines call graph verdicts with variable-level taint tracing. Determines whether the input reaching a vulnerable sink is attacker-controlled or safe (constant/config/validated). Results: 154 confirmed exploitable, 43 false positives downgraded on testbed.
- **Three-layer reachability** — Call graph (function-level) + AI taint oracle (variable-level) + AI invocation classifier (execution pattern). `--deep` flag analyzes all findings including NOT_REACHABLE.
- **Dashboard AI badges** — Findings show AI verification status: green "AI ✓" (confirmed exploitable), blue "AI ↓" (safe), red "AI ↑" (promoted by AI).
- **Malware guard** — AI taint analysis automatically skips files flagged by the malware scanner. Behavior (C2 download, payload exec) overrides taint verdict.
- **Prompt caching** — SHA-256 prompt hash avoids re-analyzing unchanged code across runs.
- **Branch cleanup** (`enzo clean`) — Purge accumulated fix/batch branches. `--dry-run` to preview.

### CI/CD

- **One-command CI integration** — GitHub Actions, GitLab CI, and Jenkins templates. Single job, no shared volumes, no coordination.
- **`--fail-on` threshold gating** — `critical | high | medium | any | none` exit code control for pipeline gates
- **Docker-based scanning** — `docker-compose.yml` with `run.sh` wrapper for containerized environments

### Distribution

- **Two-repo architecture** — `reach-core` (private source) + `reach-dist` (public distribution: wheels, installer, docs, CI/CD templates)
- **Automated release pipeline** — tag-triggered: transpile → matrix build → sign → GitHub release → reach-dist sync

---

## Upgrading

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --clean
```

Clean install is recommended for beta releases.

---

© 2026 Sthenos Security. All rights reserved.
