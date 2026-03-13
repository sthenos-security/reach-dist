# REACHABLE Changelog

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

- **AI-assisted remediation engine** — included as a preview. Automated fix suggestions for CVE, CWE, and secrets findings. Full release targeted for a future beta.

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
