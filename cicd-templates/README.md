# REACHABLE CI/CD Templates

One command. All scanners run concurrently in a single process. No shared volumes, no coordination.

```
reachctl scan . --ci --fail-on high --sarif results.sarif
```

## Files

| Platform | File |
|---|---|
| GitHub Actions | `github-actions/reachable.yml` |
| GitLab CI | `gitlab/.gitlab-ci.yml` |
| Jenkins | `jenkins/Jenkinsfile` |

## Usage

Copy the file for your platform into your repo and set optional variables to override defaults.

All configs support the same variables:

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
