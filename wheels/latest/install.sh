#!/usr/bin/env bash
# REACHABLE — Latest Release Installer
# Delegates to the root installer which always resolves the latest version.
exec bash <(curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh) "$@"
