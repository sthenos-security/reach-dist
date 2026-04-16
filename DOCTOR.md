# reachctl doctor — Sample Output

The following is a sample output of `reachctl doctor` on a healthy macOS system with all tools installed and credentials configured.

```
REACHABLE SYSTEM CHECK
[1/6] System Resources
   OS:      Darwin arm64
   RAM:     16.0GB total, 8.0GB available
   Disk:    24.3GB free (/Users/you/.ollama)
   GPU:     Apple Silicon (Metal) (16.0GB)
   Ollama:  installed (not running)
[2/6] Required Tools
 Preflight check...
   git 2.50.1
   Python 3.14
   syft 1.42.1
   grype 0.109.0
   semgrep 1.159.0
   guarddog 2.4.0
   gitleaks 8.21.2 (managed)
   colima: installed (not running — will auto-start at scan time)
   docker SDK: ready — sandbox available
   grype vulnerability DB
 Preflight passed
 All tools ready
   Sandbox: colima installed (not running), docker SDK ready
[3/6] Git
   ✓ git version 2.50.1 (Apple Git-155)
[4/6] AI Engine (Ollama)
   ollama — installed (not running)
     Start Ollama now? [y/N] n
     Start as service: brew services start ollama
[5/6] Credentials
   GitHub Token           ○ SSH works, no API token
   GitHub MCP Token       ✓ valid (env:MCP_GITHUB_TOKEN)
   Anthropic API Key      ✓ valid (keychain)
   Groq API Key           ✓ valid (keychain)
   OpenRouter API Key     ✓ sk-o…b845 (keychain)
   DeepSeek API Key       — not configured (optional)
   Moonshot (Kimi) Key    — not configured (optional)
   REACHABLE Token        — not configured (free mode)
     Free tier            all signals · 1 repo · unlimited local scans
[6/6] Enzo build tools  ✓ all present
 Doctor complete.
```

## Notes

- On first run, `doctor` installs missing tools (syft, grype, semgrep, guarddog, gitleaks) automatically.
- Gitleaks is managed by REACHABLE and installed to `~/.reachable/cache/gitleaks/`.
- Colima/Docker auto-starts at scan time when the malware sandbox runs — no manual start needed.
- AI providers are auto-detected from the system keychain or environment variables. OpenRouter is recommended (single key, 300+ models, lowest cost).
- Credentials are stored securely in the system keychain via `reachctl doctor set <credential-name>`.
- The REACHABLE token is optional for free tier (1 repo). Paid plans unlock more repos and cloud features.
- Missing build tools (go, node, cargo, etc.) are needed only for patch validation in `reachctl fix`.

## Setting Up Credentials

```bash
reachctl doctor set openrouter-api-key    # recommended — single key, all providers
reachctl doctor set anthropic-api-key     # Claude (best accuracy)
reachctl doctor set groq-api-key          # Groq (fast, cheap)
reachctl doctor status                    # show all configured credentials
```
