# REACHABLE

Security scanner that shows which vulnerabilities are actually reachable through your code.

## Install

```bash
git clone https://github.com/sthenos-security/reach-dist.git
cd reach-dist
./install.sh
```

Requires GitHub collaborator access. The installer handles authentication via `gh auth login`.

## Get Started

```bash
reachctl primer
```

## Quick Scan

```bash
reachctl scan /path/to/your/repo
```

## Upgrade

```bash
./install.sh --update       # Preserves data
./install.sh --clean        # Fresh start (recommended during beta)
```

## Uninstall

```bash
pip3 uninstall reachable
rm -rf ~/.reachable
```

## Requirements

- Python 3.10–3.14
- macOS or Linux (x86_64 / ARM64)

## Support

adazzi@sthenosec.com

---

© 2026 Sthenos Security. All rights reserved.
