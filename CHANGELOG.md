# REACHABLE Changelog

All notable changes to REACHABLE are documented here.

---

## [1.0.0-beta14] - 2026-02-02

### Fixed
- **DLP false positives**: Word-boundary regex in `sources.py` — `pan` no longer matches `span`, `company`, `expand`; `name` no longer matches `serviceName`, `filename`
- **Credential file false positives**: `.npmrc`, `.pypirc`, `.yarnrc` now content-aware — only flags files with actual credentials (`_authToken`, `password=`), not config-only files
- **Template variable false positives**: `${{ secrets.GITHUB_TOKEN }}`, `${{ steps.X.outputs.token }}`, `${VAR_NAME}` no longer flagged as hardcoded secrets
- **CI workflow false positives**: Job names like `secrets:` and commands like `detect-secrets scan` no longer trigger generic_secret detection
- **MCP error logging**: Fixed f-string bug in `mcp_github.py` — error messages now show actual errors instead of literal `{error_str}`
- **Library tag matching**: Semver-aware matching in `lib_manager.py` — `4.5.3` can no longer fuzzy-match to `v4.0.3` (requires exact major.minor)
- **Colima sandbox messaging**: Fixed contradictory "Colima running" + "Docker not running" messages
  - `_check_colima_status()` now verifies Docker daemon accessibility, not just Colima process existence
  - New status `docker_not_ready` with clear fix instructions (`colima stop && colima start`)
- **Dashboard Unknown display**: Fixed "unknown Unknown" literal — now shows `❓ Unknown (review)` properly

### Changed
- **Primer documentation**: Expanded dynamic malware sandbox section for macOS users
  - Clear setup instructions: `reachctl sandbox --init` or manual `brew install colima docker && colima start`
  - Management commands: `--init`, `--remove`, status check
  - Troubleshooting section for common issues
  - Clarified that static malware analysis (GuardDog) always runs; sandbox is optional but recommended

### Documentation
- Updated all version references from b13 to b14
- `reachctl primer` now includes complete Colima setup and troubleshooting guide

---

## [1.0.0-beta13] - 2026-01-31

### Added
- **DLP/PII Security Scanner**: Data Loss Prevention module with automatic PII detection
  - Supports 25+ PII types: SSN, credit cards, API keys, passwords, health data, etc.
  - Two-gate validation system reduces false positives by ~60%
  - Gate 1: Path-based suppression (test files, fixtures, mocks, docs, examples)
  - Gate 2: Token validation (Luhn check for credit cards, format validation for SSNs, etc.)
  - Sanitizer detection: Identifies masked/redacted data patterns
  - Integrated into dashboard with dedicated DLP panel
- **AI Security Scanner**: OWASP LLM Top 10 detection (LLM01-LLM10)
  - Prompt injection detection
  - Insecure output handling
  - Training data poisoning patterns
  - Model DoS vulnerabilities
  - Guard detection for protected AI endpoints

### Fixed
- **Trends chart totals**: DLP and AI findings now correctly included in scan history totals
  - Fixed race condition where `complete_scan()` ran before DLP findings were stored
  - Scans table now updated after DLP storage to include all signal types
- **Dashboard data consistency**: Pipeline integrity check now validates all stages
  - Raw → DB → Dashboard counts verified at scan completion

### Changed
- Dashboard summary now shows all 8 signal types:
  - CVE Vulnerabilities, Malware (Static/Dynamic), Exposed Secrets
  - Code Weaknesses (CWE), Config Issues, AI Security, DLP/PII
- Noise reduction calculation includes DLP and AI filtered findings
- Data integrity check added to scan completion output

### Security
- DLP findings include regulation mapping (GDPR, HIPAA, PCI-DSS, SOX, CCPA)
- Severity auto-calculated based on PII type and exposure context

---

## [1.0.0-beta10] - 2026-01-18

### Fixed
- **Dashboard data embedding**: Fixed silent failure in HTML data injection
- **Reachability mapping**: Fixed incorrect `is_reachable` values for secrets and config
  - Unknown secrets now correctly set `is_reachable=True` (conservative approach)
  - Config issues now correctly set `is_reachable=None` (runtime-dependent)
- **Python cache issues**: `reachctl` now clears `__pycache__` and uses `--no-cache-dir` for pip installs
- **Dashboard JS fixes**: 
  - Fixed duplicate `dashboardData` declaration causing console errors
  - Added conditional `renderDashboard()` call (only when required elements exist)
  - Proper `allIssues` array initialization

### Changed
- Dashboard trends chart now displays correctly with multiple scans
- Improved source code installation reliability
- **Dead code cleanup**: Removed legacy `html_builder.py`, `index.html`, empty `templates/` dir

### Removed
- Old single-page dashboard builder (replaced by multi-page `html_builder_v2.py`)

---

## [1.0.0-beta8] - 2026-01-13

### Added
- **Installer upgrade support**: `--update` flag backs up existing data before upgrade
- **Clean install option**: `--clean` flag removes existing data (recommended for beta upgrades)
- **Version pinning**: `--version` flag to install specific versions
- **Risk Inventory collapsible**: Table now collapsible within Engineering Remediation panel
- **Not Fixable count**: CVE Summary now shows both "Fixable Now" and "Not Fixable" counts

### Changed
- Dashboard v4.5.23 with improved UI:
  - Risk & Posture panel: Red accent (was green - semantically incorrect)
  - Engineering Remediation panel: Indigo accent (was orange)
  - Funnel title centered: "REACHABLE Analysis Funnel"
  - Simplified action text: "X issues require immediate remediation"
  - Review text: "X issues require review/investigation (unknown reachability)"
  - Counter colors: Red for immediate (ef4444), Amber for review (f59e0b)
- Removed "Packages to Remove" metric (unreliable data source)
- Renamed "Static Analysis" → "Static Malware" throughout
- Renamed "Dynamic Analysis" → "Dynamic Malware" throughout
- Removed duplicate panel headers

### Fixed
- Duplicate "Engineering Remediation" header removed
- Funnel title font and alignment restored
- DIV balance issues in dashboard template

### Upgrade Notes
During beta, database schema may change between versions. **Recommended upgrade procedure:**

```bash
# Clean install (removes scan history, avoids compatibility issues)
curl -sSL .../install.sh | bash -s -- --clean

# Or upgrade with backup (keeps data, may have issues)
curl -sSL .../install.sh | bash -s -- --update
```

---

## [1.0.0-beta7] - 2026-01-12

### Added
- **Call Graph Visualization** in dashboard - click "Yes (call graph)" to see reachability path
- Transitive dependency chains shown: `app_func → direct_import → vulnerable_package`
- `call_path` and `reachability_path` fields populated for CVEs, CWEs, and Secrets
- **macOS Universal2 wheels** - single wheel supports both Intel and Apple Silicon Macs

### Changed
- Dashboard "Reachable" column now shows "Yes (call graph)" when path data available
- Improved reachability path display with color-coded steps (green=entry, gray=middle, red=vulnerable)
- macOS wheels now use `universal2` platform tag (supports Intel + Apple Silicon)
- Installation path is now `~/.reachable/venv/bin` (virtual environment based)

### Fixed
- Installer script now correctly handles all Python versions and platforms
- PATH documentation corrected to use `~/.reachable/venv/bin`

### Note
- GuardDog/Static Malware findings do not have call paths (file-based detection)
- Full lib→lib→lib transitive chains planned for future release

---

## [1.0.0-beta4] - 2026-01-11

### Added
- Multi-Python wheel support: Python 3.10, 3.11, 3.12, 3.13, 3.14
- Multi-platform support: Linux (x86_64, ARM64), macOS (Apple Silicon)
- 15 wheels per release (5 Python versions × 3 platforms)
- Automated installer script (`install.sh`)
- CI/CD-based wheel builds via GitHub Actions

### Changed
- `requires-python` updated to `>=3.10`
- Wheel naming convention with explicit `cpXYZ` tags
- Release process now fully automated via CI/CD

---

## [1.0.0-beta3] - 2026-01-11

### Added
- Initial multi-Python wheel builds
- Platform matrix documentation

### Changed
- CI/CD workflow for multi-platform builds

---

## [1.0.0-beta2] - 2026-01-11

### Added
- `reachctl primer` command for quick-start guide
- `reachctl sandbox` no-arg fix (defaults to --status)
- Version display with git commit info

### Changed
- Improved selftest output formatting

---

## [1.0.0-beta1] - 2026-01-10

### Added
- Comprehensive platform dependencies documentation
- Storage cleanup with filesystem + database trimming
- Per-repository database (repo.db) architecture
- Distribution repository with platform-specific wheels

### Changed
- Public versioning scheme (1.0.0-betaN for pre-release)
- GuardDog isolated venv location

### Fixed
- Database storage path consistency
- Scan cleanup now removes both filesystem and database entries

---

## Upgrading Between Versions

### Standard Upgrade (preserves data)

```bash
curl -sSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --update
```

### Clean Upgrade (recommended for beta)

```bash
curl -sSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --clean
```

### If You Encounter Issues

```bash
# Remove all data and reinstall
rm -rf ~/.reachable
curl -sSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash
```

---

## License

Proprietary - © 2026 Sthenos Security. All Rights Reserved.
