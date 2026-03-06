# Release Notes

New versions of REACHABLE are released periodically and made available in this repository automatically. No action is required on your part — the installer always fetches the latest available version.

---

## Staying Up to Date

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash -s -- --update
```

This backs up your existing data and installs the latest release.

---

## Wheel Availability

Each release provides **15 wheels** covering:

| Platform | Architecture | Python Versions |
|----------|--------------|-----------------|
| Linux | x86_64 | 3.10, 3.11, 3.12, 3.13, 3.14 |
| Linux | ARM64 | 3.10, 3.11, 3.12, 3.13, 3.14 |
| macOS | Universal (Intel + Apple Silicon) | 3.10, 3.11, 3.12, 3.13, 3.14 |

Wheels are located in `wheels/v<version>/`.

---

## Verifying a Release

See [VERIFICATION.md](VERIFICATION.md) for instructions on verifying wheel authenticity using Cosign.

---

## Questions?

Contact: info@sthenosec.com

---

© 2026 Sthenos Security. All rights reserved.
