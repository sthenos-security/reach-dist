# REACHABLE Changelog

All notable changes to REACHABLE are documented here.

---

## [1.0.0-beta10] - 2026-01-16

### Fixed
- **Dashboard data embedding**: Fixed silent failure in HTML data injection
- **Reachability mapping**: Fixed incorrect `is_reachable` values for secrets and config
  - Unknown secrets now correctly set `is_reachable=True` (conservative approach)
  - Config issues now correctly set `is_reachable=None` (runtime-dependent)
- **Python cache issues**: `reachctl` now clears `__pycache__` and uses `--no-cache-dir` for pip installs

### Changed
- Dashboard trends chart now displays correctly with multiple scans
- Improved source code installation reliability

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
