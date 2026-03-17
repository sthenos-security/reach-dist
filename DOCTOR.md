# reachctl doctor — Sample Output

The following is a sample output of `reachctl doctor` on a healthy macOS system with all tools installed and credentials configured.

```
REACHABLE SYSTEM CHECK
[1/6] System Resources
   OS:      Darwin arm64
   RAM:     16.0GB total, 8.0GB available
   Disk:    66.9GB free (/Users/you/.ollama)
   GPU:     Apple Silicon (Metal) (16.0GB)
   Ollama:  installed (not running)
[2/6] Required Tools
 Preflight check...
   git 2.50.1
   Python 3.14
   syft 1.42.1
   grype 0.109.0
   semgrep 1.154.0
   guarddog 2.4.0
   sandbox (colima/docker)
   grype vulnerability DB
 Preflight passed
 All tools ready
[3/6] Git
   ✓ git version 2.50.1 (Apple Git-155)
   Credentials: reachctl auth status
[4/6] Optional Enhancements
   trufflehog 3.93.6 — active secret verification available
   joern 4.0.490 (Java 17)
   ollama — installed (not running)
     Start Ollama now? [y/N] n
     Start as service: brew services start ollama
       (auto-starts on boot, restarts on crash)
[5/6] Credentials
   GitHub Token           ○ SSH works, no API token
   GitHub MCP Token       ✓ valid (env:MCP_GITHUB_TOKEN)
   Anthropic API Key      ✓ valid (keychain)
   Groq API Key           ✓ valid (keychain)
[6/6] Enzo Build Tools
   mvn ✓    gradle ✓    go ✓    cargo ✓
   node ✓   bundle ✓    composer ✓
 Doctor complete
```

## Notes

- On first run, `doctor` installs missing tools (syft, grype, semgrep, guarddog) automatically.
- `joern` is optional — required only for full JS/TS call graph analysis.
- `trufflehog` is optional — enables active secret verification.
- Credentials are stored in the system keychain via `reachctl auth login`.
- Missing build tools can be fixed with `reachctl enzo doctor --fix`.
