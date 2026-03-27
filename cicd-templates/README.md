# REACHABLE CI/CD Templates

One command. All scanners run concurrently in a single process. No shared volumes, no coordination.

```
reachctl scan . --ci --fail-on high --sarif results.sarif
```

## Templates

### Standard (static analysis + local sandbox)

| Platform | File | Copy to |
|---|---|---|
| GitHub Actions | `github-actions.yml` | `.github/workflows/reachable.yml` |
| GitLab CI | `gitlab-ci.yml` | `.gitlab-ci.yml` (repo root) |
| Jenkins | `Jenkinsfile` | `Jenkinsfile` (repo root) |

### With Remote Detonation (Firecracker sandbox)

For Linux CI/CD runners with a dedicated detonation host. See [`../detonation/RUNBOOK.md`](../detonation/RUNBOOK.md) for host setup.

| Platform | File | Copy to |
|---|---|---|
| GitHub Actions | `github-actions-detonation.yml` | `.github/workflows/reachable-detonation.yml` |
| GitLab CI | `gitlab-ci-detonation.yml` | `.gitlab-ci.yml` (repo root) |

**Required secrets/variables:** `REACHABLE_SANDBOX_HOST` (IP of detonation host), `REACHABLE_SANDBOX_KEY` (Ed25519 private key).

## Variables

All templates support the same configuration:

| Variable | Default | Description |
|---|---|---|
| `REACHABLE_DIST_REPO` | `sthenos-security/reach-dist` | Distribution repo |
| `REACHABLE_VERSION` | _(latest)_ | Pin a specific version |
| `FAIL_THRESHOLD` | `high` | `critical\|high\|medium\|any\|none` |

**GitHub Actions:** set as repo variables (Settings → Variables).
**GitLab CI:** set as CI/CD variables (Project → Settings → CI/CD → Variables).
**Jenkins:** set as environment variables or override in the Jenkinsfile.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Clean |
| `2` | Findings above threshold |
| `1` | Scan error |
