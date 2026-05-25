---
name: upgrade-github-actions
description: Scan and upgrade all GitHub Actions in a project to their latest major versions, confirmed via GitHub API
version: 1.0.0
tags: [github-actions, ci, upgrade, workflow, dependabot]
---

# Upgrade GitHub Actions

When the user asks to upgrade GitHub Actions, follow this workflow:

## Workflow

1. **Scan workflow files**: Find all `.yml`/`.yaml` files under `.github/workflows/`
2. **Extract current action versions**: Identify all `uses:` references and their version tags (including third-party actions)
3. **Query latest versions**: Use the GitHub API to confirm each action's latest version (see "Version Query Method" below)
4. **Compare differences**: List actions that need upgrading in this format:

| File | Action | Current Version | Latest Version | Notes |
|------|--------|----------------|----------------|-------|

5. **Batch update after confirmation**: Once the user confirms, modify all workflow files
6. **Validate**: Check workflow file syntax (indentation, quotes, etc.)
7. **Commit and push**: Commit message format: `chore: bump github actions (<brief action list>)`

## Version Query Method (Critical)

**You MUST use the GitHub API. Do NOT rely on web search to determine versions.** Web search results have severe caching issues and return outdated data, leading to incorrect version judgments.

### The only authoritative method: fetch GitHub Releases API

```
https://api.github.com/repos/{owner}/{repo}/releases/latest
```

Extract the `tag_name` field from the returned JSON — that is the latest version.

Example: Query latest version of `docker/login-action`:
- fetch `https://api.github.com/repos/docker/login-action/releases/latest`
- Read `"tag_name": "v4.2.0"` from response → major version is `@v4`

### Fetch the API for each action individually. Do NOT skip any. Do NOT substitute with web search.

## Common Docker-Related Actions Version Reference

> **Last verified via API: May 2026**

- `actions/checkout@v6`
- `docker/setup-qemu-action@v4`
- `docker/setup-buildx-action@v4`
- `docker/login-action@v4`
- `docker/bake-action@v7`
- `docker/build-push-action@v7`
- `peter-evans/dockerhub-description@v5`

> If versions differ from the above, an upgrade is needed. When performing upgrades, you MUST verify via API whether a newer major version exists — do not rely solely on this table.

## Important Notes

- Use major version tags (e.g., `@v4`) rather than full version numbers (e.g., `@v4.1.0`), so minor/patch updates are received automatically
- Before upgrading a major version, quickly check for breaking changes (look at the `body` field in release notes)
- Docker-related actions (docker/*) typically release new major versions in sync — if one gets a major bump, others likely do too
- If the project has dependabot/renovate configured and related PRs exist, close those PRs after upgrading
- All workflow files in the same repository should use consistent action versions
- After upgrading, observe one CI run to confirm no breaking changes

## Security Recommendations

- When upgrading, check for permission changes in actions (especially `permissions`-related)
- Monitor GitHub official security advisories and promptly upgrade action versions with known vulnerabilities
