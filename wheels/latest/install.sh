#!/usr/bin/env bash
# REACHABLE — Latest Release Installer
# Delegates to the root installer which always resolves the latest version.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/wheels/latest/install.sh | bash
set -e
exec bash <(curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh) "$@"
