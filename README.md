# REACHABLE

Security scanner that shows which vulnerabilities are actually reachable through your code.

## Dashboard

<p align="center">
  <img src="assets/dashboard-ai-tab.png" alt="REACHABLE Dashboard — AI/LLM/Agentic Security" width="900">
</p>

The interactive dashboard shows scan results across six tabs: Risk & Posture, Remediation Overview, Security Issues, OWASP Top 10, AI/LLM/Agentic, and DLP/PII. The AI Attack Surface Map visualizes the full LLM pipeline — from user input through prompt guards, model core, tool use, RAG, and output — mapping OWASP LLM Top 10 and Agentic Security Index findings to each stage.

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

## Verify Signatures

All wheels are signed with [Sigstore](https://sigstore.dev) cosign. See [VERIFICATION.md](VERIFICATION.md) for details.

```bash
brew install cosign
cosign verify-blob \
    --bundle reachable-*.whl.cosign.bundle \
    --certificate-identity-regexp="https://github.com/sthenos-security/reach-core/.*" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    reachable-*.whl
```

## Requirements

- Python 3.10–3.14
- macOS or Linux (x86_64 / ARM64)

## Support

adazzi@sthenosec.com

---

© 2026 Sthenos Security. All rights reserved.
