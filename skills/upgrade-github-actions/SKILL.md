---
name: upgrade-github-actions
description: 'Scan a repository''s workflow files and upgrade every GitHub Action to its latest major version, verified live against the GitHub API instead of memory or web search. Use this skill whenever the user wants to upgrade, bump, audit, or check GitHub Actions versions — e.g. "upgrade github actions", "bump actions to latest", "are my workflow actions outdated", "update actions/checkout in my CI" — even for a single action or a quick check.'
---

# Upgrade GitHub Actions

The bundled script does the read-only discovery: it scans workflow files,
queries the GitHub API for each action's latest version, and prints a
comparison. Editing files, judging breaking changes, and committing stay
with you — those need judgment, not automation.

Never determine action versions from memory or web search. Model knowledge
is frozen at training time and search results are heavily cached; both
routinely report versions that are one or two majors behind. The script
exists precisely to replace that guesswork with a live API answer.

## Workflow

1. Run the script from the skill directory (read-only, safe to run first):

   ```bash
   ./scripts/check-actions.sh --dir <repo-root>          # human-readable table
   ./scripts/check-actions.sh --dir <repo-root> --json   # machine-readable
   ```

2. Present the comparison to the user: which actions are outdated, current
   vs latest version, and which files reference them. If everything is
   up to date, say so and stop.

3. Wait for the user to confirm before modifying any workflow file.

4. Apply the upgrades:
   - Use major version tags (`@v5`), not full versions (`@v5.1.0`), so
     minor and patch updates arrive automatically.
   - Keep versions consistent: the same action should use the same version
     across all workflow files in the repository.
   - Before bumping a major version, skim the release notes for breaking
     changes (`gh api repos/<owner>/<repo>/releases/latest --jq .body`)
     and surface anything relevant to the user.

5. Validate the edited files: run `actionlint` if available, otherwise
   review the diff carefully (indentation, quoting).

6. Offer to commit with message `chore: bump github actions (<brief list>)`.
   Commit and push only after the user agrees. If dependabot or renovate
   has open PRs for the same bumps, point them out so the user can close
   them. Suggest watching the next CI run to catch breaking changes.

## Reading the script output

Each unique (action, version) pair gets a STATUS:

- `outdated` — a newer major version exists; candidate for upgrade.
- `up-to-date` — current major matches the latest.
- `sha-pinned` — pinned to a full commit SHA, usually a deliberate security
  choice. Do not silently replace it with a mutable tag. Ask the user; if
  they want to stay SHA-pinned, update to the commit SHA of the latest
  release instead.
- `unknown` — the version could not be compared (branch ref, or the API
  query failed). Investigate manually.

Local actions (`./path`) and Docker images (`docker://...`) are excluded —
they have no GitHub version to compare.

## How the script queries versions

For each unique action repository it fetches
`repos/{owner}/{repo}/releases/latest` and reads `tag_name`; repositories
that only tag without publishing releases fall back to the tags list
(marked `latest_source: tag` in JSON output). It prefers an authenticated
`gh` CLI when available; otherwise it uses curl, where an unauthenticated
client is limited to 60 API calls per hour — set `GITHUB_TOKEN` if the
repository references many actions.

## Exit codes

`0` scan and query completed (regardless of whether upgrades are needed);
`1` usage or runtime error (including exhausted API rate limit);
`2` precondition failed (no `.github/workflows/` directory, or neither
`gh` nor `curl` available).
