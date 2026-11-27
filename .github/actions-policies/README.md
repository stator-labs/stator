# Actions event policies

GitHub stores these in repo settings, not in git. These files are the record. Apply or update one with:

```bash
gh api -X POST repos/stator-labs/stator/actions/policies -H "X-GitHub-Api-Version: 2026-03-10" --input .github/actions-policies/<file>.json
```

| File | Live id | Why |
|---|---|---|
| `policy-check.json` | 18024 | GitHub blocks `pull_request_target` in public repos from 2026-12-02 ([changelog](https://github.blog/changelog/2026-11-02-pull_request_target-blocked-by-default-december-2)). `Policy: trust paths` needs it so it runs main's copy and a PR cannot edit its own judge. Scoped to `policy.yml`; `merge_group` is listed because the allow-list blocks unlisted events. |

**Why not switch the check to `pull_request`?** Then the PR's own copy of `policy.yml` runs, so a PR could rewrite the check that judges it. CODEOWNERS would catch that only once agent PRs run as `stator-bot` (STAT-46).
