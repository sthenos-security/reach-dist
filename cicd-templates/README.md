# REACHABLE CI/CD Templates

Copy the template for your CI platform into your repo. No configuration required to get started.

## Recommended: Universal Pipeline

One job, one runner, all scanners run concurrently inside REACHABLE.
Works on managed runners and self-hosted runners without any changes.
**Typical runtime: 60–90 seconds.**

| Platform | File | Copy to |
|----------|------|---------|
| GitHub Actions | `github-actions/reachable.yml` | `.github/workflows/reachable.yml` |
| GitLab CI | `gitlab/.gitlab-ci.yml` | `.gitlab-ci.yml` |
| Jenkins | `jenkins/Jenkinsfile` | `jenkins/Jenkinsfile` |

## Variables

All variables are optional — defaults work out of the box.

| Variable | Default | Description |
|----------|---------|-------------|
| `REACHABLE_DIST_REPO` | `sthenos-security/reach-dist` | Distribution repo |
| `REACHABLE_VERSION` | latest | Pin a specific version |
| `FAIL_THRESHOLD` | `high` | Gate threshold: `critical` \| `high` \| `medium` \| `any` \| `none` |
| `RUNNER_LABEL` | `ubuntu-latest` | Runner label (GitHub/Jenkins only) |

## Self-Hosted Runners

**GitHub Actions:** Set the `RUNNER_LABEL` repo variable to your runner label.

**GitLab CI:** Uncomment the `tags` block in the template and set `RUNNER_TAG`.

**Jenkins:** Replace `agent any` with `agent { label 'your-label' }`.

No shared volumes, no network mounts, no distributed coordination needed —
REACHABLE handles concurrency internally on a single runner.
