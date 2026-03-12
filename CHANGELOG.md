# REACHABLE Changelog

---

## [1.0.0b29]

- Malware: Fixed empty `package_name` on 288 semgrep malware findings — normalizer now derives package from file path relative to repo root (22 distinct packages detected)
- Malware: Sandbox `packages_tested` metric now flows from raw scanner output through to dashboard (`sandbox_packages_tested=190` verified end-to-end)
- Malware: Sandbox findings fully ingested into DB (42 findings, 14 distinct malicious packages)
- Malware: 4-counter metrics verified — static_confirmed/suspicious + dynamic_confirmed/suspicious all reconciled against DB
- Dashboard: Sandbox metrics object added to data.json (packages_tested, malicious, suspicious, clean, verdict)
- Pipeline: Full 4-layer audit verified (raw → DB → data.json → dashboard) — all 7 signal types reconcile exactly
- CLI: `reachctl selftest` — faster, no longer runs full scan infrastructure; validates install, tools on PATH, and DB access
- CLI: `reachctl selftest --unit / --integration / --full` flags unchanged
- Build: release pipeline hardened — per-job timeouts, automatic cancellation of duplicate runs, immediate failure propagation across build matrix
- Build: workflow linting added as mandatory gate before any build starts
- **Enzo** (experimental): AI-assisted remediation engine included as preview — not fully tested, full release targeted for b30+

---

## [1.0.0b28]

- CI/CD: Universal single-command pipeline for GitHub Actions, GitLab CI, and Jenkins — replaces all multi-job reference variants
- CI/CD: `--ci` flag enables quiet output, structured exit codes, and auto-gates on `--fail-on critical`
- CI/CD: `--no-dashboard` flag for faster CI scans when dashboard artifact is not needed
- CI/CD: Docker scan consolidates to single `docker-compose.yml` with `--no-dashboard` opt-in via `run.sh`
- Dashboard: Fixed `reachability_coverage_pct` showing zero — join timing issue in `getReachabilityCoverage()`
- Dashboard: Fixed 31+ bugs across `main.js`, `tabs.js`, `owasp-cards.js`, `dashboard-styles.css` — GRC framework inferral, CWE hex hash display, CSV export filters, OWASP card heights, counter/table mismatches, color palette violations
- Dashboard: SLA logic — unfixable CVEs show `NO FIX`, unknown severity shows `ASSESS`; fix status filter added
- Dashboard: Config/IaC terminology unified to `Config` throughout UI and DB
- Dashboard: Removed INFO from severity filter; cleaned up risk filter labels
- Dashboard: Fixed `_DASHBOARD_HTML_READ_LIMIT` constant (bumped to 768 KB)
- Dashboard: Fixed trends chart DLP race condition (`complete_scan()` called before DLP storage)
- Supply chain: Phase 5 unresolved package tracking with fuzzy matching, DB operations, and CLI aliases
- Supply chain: Fixed `_to_advisory_dicts()` dropping `is_direct` field; fixed `toggleGroup` badge hardcoding
- Reachability: Fixed write-path ban for v1 `call_path` fields (T-CG28); fixed secret reachability downgrade bug (T-CG29); fixed `callable_functions` multi-parent BFS crash (T-CG30)
- Scanning: Upgraded Syft (v1.42.1) and Grype (v0.109.0) with version-mismatch detection in `preflight.py`
- CLI: `reachctl selftest` Phase 4 — `test_cli_comprehensive.py` wired in (893 passed, 0 failed)
- CLI: Fixed stale `template-shell-compiled.html` and `TestSemgrepRules` pyyaml guard
- CLI: Emoji removed from 157 Python source files
- Distribution: Consolidated CI/CD into `reach-dist-cicd`; removed `reach-cicd`
- Distribution: Cosign keyless signing with GitHub OIDC on all wheel releases

---

## [1.0.0b17]

- Release integrity: SHA-256 checksum and Sigstore/cosign signature verification on every install
- Installer: `doctor` now runs before `selftest` during installation
- `reachctl version`: removed tool status (belongs in `reachctl doctor`)
- `reachctl selftest`: accurate tool paths shown, managed tools only resolved from `~/.reachable`
- `reachctl pipeline init`: fixed session ID capture in CI (output via `print()`, `--json` flag)
- CI/CD templates: fixed serial scan session ID parsing

---

## [1.0.0b16]

- Dashboard improvements: new tabs, improved rendering, badge fixes
- Supply chain analysis: popularity and activity scoring, dependency confusion detection
- Package health pipeline integrated into scan workflow
- Call graph visualization enhancements
- Reachability correlation engine improvements
- CI/CD template updates for GitHub Actions, GitLab, and Jenkins
- Dependency updates: Syft, Grype

---

## [1.0.0b10]

- Dashboard v2: tabbed interface, split-component architecture
- DLP/PII scanner added
- AI/LLM security module: OWASP LLM Top 10, MITRE ATLAS
- Supply chain sandbox: behavioral testing via Docker
- Compliance framework mapping: FedRAMP, CMMC 2.0, NIST, SOC2, PCI-DSS
- Multi-platform wheel builds: Linux x86_64/ARM64, macOS Universal

---

## [1.0.0b8]

- Installer upgrade support: `--update`, `--clean`, `--version` flags
- Dashboard UI improvements
- Improved remediation workflow

---

## [1.0.0b7]

- Call graph visualization in dashboard
- macOS Universal2 wheel support
- Initial beta release

---

## Upgrading

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --update
```

For beta releases, a clean install is recommended:

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --clean
```

---

© 2026 Sthenos Security. All rights reserved.
