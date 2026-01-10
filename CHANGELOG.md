# REACHABLE Changelog

All notable changes to REACHABLE are documented here.

## Version Numbering

| Public Version | Internal Version | Status |
|----------------|------------------|--------|
| 1.0.0-beta1 | 4.6.0 | Current |
| 1.0.0 | 4.6.x (stable) | Planned GA |

---

## [1.0.0-beta1] - 2026-01-10

*Internal version: 4.6.0*

### Added
- Comprehensive platform dependencies documentation
- Dependency map showing pip vs system installations
- Storage cleanup with filesystem + database trimming
- Per-repository database (repo.db) architecture
- Distribution repository with platform-specific wheels

### Changed
- Public versioning scheme (1.0.0-betaN for pre-release)
- GuardDog isolated venv location now respects REACHABLE_CACHE_DIR
- Improved CI/CD caching documentation

### Fixed
- Database storage path consistency
- Scan cleanup now removes both filesystem and database entries

---

## Pre-release History (Internal Versions)

### [4.5.9] - 2026-01-10
- Platform dependencies documentation
- Dependency map creation
- Distribution repo setup

### [4.5.8] - 2026-01-09
- Per-repository SQLite database (repo.db)
- Historical scan tracking with branch/commit metadata
- `reachctl db --status/--trim/--optimize` commands

### [4.5.7] - 2026-01-08
- Executive dashboard with risk posture indicators
- Noise reduction metrics and workload calculations
- Branding integration (Sthenos logo)

### [4.5.0] - 2026-01-01
- CI/CD integration flags: `--fail-on`, `--format`, `--quiet`
- SARIF output for GitHub Security tab
- Markdown report generation

### [4.4.0] - 2025-12-15
- 11 compliance frameworks (FedRAMP, CMMC 2.0, HIPAA, etc.)
- CWE-based policy mapping
- Threat intelligence integration

### [4.3.0] - 2025-12-01
- GuardDog malware detection integration
- Semgrep secrets scanning
- Dynamic malware sandbox (Colima on macOS)

### [4.0.0] - 2025-11-01
- Multi-language support (Python, JavaScript, Go, Java, Rust)
- Reachability analysis engine
- Interactive HTML dashboard
- Complete architecture rewrite
- New CLI: `reachctl`

---

## License

Proprietary - © 2026 Sthenos Security. All Rights Reserved.
