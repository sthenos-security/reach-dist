# `@sthenos-security/reach-ghpkg-smoke-fixture`

Minimal smoke-only fixture package for validating private `npm.pkg.github.com` access.

Expected validation flow:

1. Publish this package to GitHub Packages
2. Restrict package visibility/access as needed in GitHub
3. Fetch it with:

```bash
./scripts/test-github-package.sh @sthenos-security/reach-ghpkg-smoke-fixture 0.0.0-smoke.1
```
