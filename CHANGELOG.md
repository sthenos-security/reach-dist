# REACHABLE Changelog

All notable changes to REACHABLE are documented here.

---

## [1.0.0-beta7] - 2026-01-12

### Added
- **Call Graph Visualization** in dashboard - click "Yes (call graph)" to see reachability path
- Transitive dependency chains shown: `app_func → direct_import → vulnerable_package`
- `call_path` and `reachability_path` fields populated for CVEs, CWEs, and Secrets

### Changed
- Dashboard "Reachable" column now shows "Yes (call graph)" when path data available
- Improved reachability path display with color-coded steps (green=entry, gray=middle, red=vulnerable)

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

### Removed
- macOS Intel (x86_64) wheels (GitHub retired Intel Mac runners)
- Intel Mac users can install from source

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

## Wheel Matrix

Each release includes **15 wheels**:

| Platform | Architecture | Python Versions |
|----------|--------------|-----------------|
| Linux | x86_64 | 3.10, 3.11, 3.12, 3.13, 3.14 |
| Linux | ARM64 | 3.10, 3.11, 3.12, 3.13, 3.14 |
| macOS | Apple Silicon | 3.10, 3.11, 3.12, 3.13, 3.14 |

> **Note:** macOS Intel wheels not available. Contact support if needed.

---

## Platform Tags Reference

| Tag | Platform |
|-----|----------|
| `manylinux_2_28_x86_64` | Linux x86_64 |
| `manylinux_2_28_aarch64` | Linux ARM64 |
| `macosx_14_0_arm64` | macOS Apple Silicon |

---

## License

Proprietary - © 2026 Sthenos Security. All Rights Reserved.
