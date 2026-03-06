# REACHABLE Changelog

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
