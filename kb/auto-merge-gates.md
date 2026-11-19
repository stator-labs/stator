---
title: Auto-merge gates
updated: 2026-11-19
---

# Auto-merge gates

When may a PR merge without a human clicking Merge? This page gives the evidence, the gates that follow from it, and what is still open. The rules are in [AGENTS.md](../AGENTS.md#human-in-the-loop). Why humans stay in the loop: [human-in-the-loop](human-in-the-loop.md).

**Result.** Auto-merge is safe for small docs, KB and template PRs once three gates hold. Infra, pipeline, identity and policy files stay human-merged. One hole needs Yaaf: agents and Yaaf share one GitHub identity, so GitHub cannot tell them apart.

## Evidence
Confidence: **high** = official docs or a primary source. **medium** = a named researcher, or a paper read through summaries. **low** = vendor data or unverified.

| # | Finding | Source | Conf. | What it changes |
|---|---|---|---|---|
| 1 | A workflow skipped by `paths:` leaves its required checks pending, so the PR blocks forever. | [GitHub docs](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks) | high | Required checks must always report. Done: `tofu-gate`. |
| 2 | Auto-merge needs required checks or reviews. It turns off when someone without write access pushes. | [GitHub docs](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/automatically-merging-a-pull-request) | high | The checks are the gate. Auto-merge only removes the waiting. |
| 3 | A PR author cannot approve their own PR. | [GitHub docs](https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/approving-a-pull-request-with-required-reviews) | high | Review gates need a second identity. Here every PR is authored by `yaaf-some`, and the ruleset requires 0 approvals. |
| 4 | AI raises delivery throughput and still raises instability. Strong tests and fast feedback decide the outcome. | [DORA 2025](https://research.google/pubs/dora-2025-state-of-ai-assisted-software-development-report/) | medium (summaries; no primary figures read) | Gates must be automated and fast, not only reviews. |
| 5 | Agent PRs that do not merge are larger, touch more files and often fail CI. Docs tasks have the highest acceptance. 1,497 of 3,225 agent fix PRs were rejected (46%). | [arXiv 2601.15195](https://arxiv.org/abs/2601.15195), [2602.02345](https://arxiv.org/abs/2602.02345), [2602.00164](https://arxiv.org/abs/2602.00164) | medium | A size limit, and docs first. |
| 6 | 45% of LLM code in 80 tasks had security flaws. | [Veracode](https://www.veracode.com/press-release/ai-generated-code-poses-major-security-risks-in-nearly-half-of-all-development-tasks-veracode-research-reveals/) | low (vendor, synthetic tasks) | Code and infra do not auto-merge on tests alone. |
| 7 | tj-actions/changed-files: version tags were moved to a malicious commit. Over 23,000 repos were exposed. CISA lists CVE-2025-30066 as exploited. | [CISA](https://www.cisa.gov/news-events/alerts/2025/03/18/supply-chain-compromise-third-party-github-action-cve-2025-30066) | high | Keep SHA pins. Workflow changes are human-merged. |
| 8 | Gating auto-merge on the actor name (`dependabot[bot]`) is exploitable. `pull_request_target` plus a PR checkout is the usual hole. | [poutine rule](https://boostsecurityio.github.io/poutine/rules/confused_deputy_auto_merge), Synacktiv | medium | Gate on file paths and checks, never on who opened the PR. Plain `pull_request`, no secrets. |
| 9 | AI agents in CI with strong tokens and PR text in the prompt can be prompt-injected. | [Aikido](https://www.aikido.dev/blog/promptpwnd-github-actions-ai-agents) | low (vendor) | The gate is deterministic code. No model inside a gate. |
| 10 | Chance a green PR breaks `main`: about 1 in 130 on small teams, 1 in 8 above 40 engineers. | [Mergify](https://mergify.com/reports/state-of-merge-queues-2026) | low (a merge-queue vendor) | Watch `main`. Add a queue or "up to date" rule when parallel PRs grow. |
| 11 | Experienced developers were 19% slower with AI and believed they were 20% faster (16 developers, 246 tasks). | [METR](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/) | medium | Measure outcomes (table below). Do not trust the feeling of speed. |

Not found: revert rates for auto-merged agent PRs, any public data for a one-person repo, and a cooldown rule for dependency bumps. Do not cite numbers for these.

## This repo's own data (2026-11-19)
| Fact | Number | Source |
|---|---|---|
| PRs opened, merged | 18, 14 | GitHub API |
| `kb-check` runs on PRs | 23, all green, median 9 s | Actions API |
| `tofu` runs on PRs | 12: 9 green, 3 red (25%), median 48 s | Actions API |
| Red `tofu` runs on `main` pushes | 1 of 5 (the other: 2 green, 1 cancelled, 1 not finished) | Actions API |
| Required approvals in the `main` ruleset | 0 | ruleset |
| `strict_required_status_checks_policy` | false (PRs need not be up to date) | ruleset |
| Bypass actors | none | ruleset |
| PR author for all PRs | `yaaf-some`, a user | GitHub API |

`kb-check` was green on all 23 runs, including on the branches where `tofu` failed. Before `tofu-gate`, `kb-check` alone would have let those PRs auto-merge.

## Gates
| Gate | Blocks | Status |
|---|---|---|
| `kb-check` | broken KB, style, lab table | required, live |
| `tofu-gate` | failed `tofu-check` or `tofu-plan`, plan skipped for a fork | required, live |
| `tier-gate` | auto-merge on a Tier 2 PR (this page's classifier) | this PR; Yaaf adds it as required |
| `aws-apply` approval | any AWS change reaching AWS | live |
| Verify `main` | a green PR that breaks `main` (`kb-check` runs on push) | this PR |

### Tier rules (`tools/tier-classify.py`)
Default deny. A PR is Tier 1 only when every file is on the allowlist, none is a trust path, and it changes at most 300 lines.
- **Allowlist:** `*.md`, `kb/`, `templates/`, `.obsidian/`.
- **Trust, always Tier 2:** `.claude/`, `.github/`, `AGENTS.md`, `CLAUDE.md`, `tools/`, `*.tf`, `*.sh`, `platform/infra/`, `labs/*/infra/`, and the two policy pages in `kb/`.
- **Anything else** is Tier 2: a new directory needs a human until someone adds it to the allowlist.

## What this does not stop
1. **A PR can edit the workflow that checks it.** GitHub runs the PR's own copy of `pull_request` workflows. The gate runs the classifier from `main`, so editing the classifier does not help. Editing `tier-gate.yml` or `kb-check.yml` still can. Only a human review of `.github/` closes this (step 2 below).
2. **One identity.** Agents push as `yaaf-some`. A rule such as "the author may not approve" or "agents may not merge" cannot be enforced by GitHub. `.claude/settings.json` blocks the agent's own tools only.
3. **Short race.** If auto-merge is enabled while only `tier-gate` is pending, the merge can finish before the failing re-run lands. Seconds, and only when everything else is already green.
4. **Supply chain.** CI does not see a compromised release. Dependency bumps are out of scope until a cooldown rule exists.

## Rollout
1. **Now (this PR):** `tier-gate` and the `main` verify run. Yaaf adds `tier-gate` as required. Nothing else changes: agents still do not enable auto-merge.
2. **Second identity (Yaaf, Tier 2: trust):** a GitHub App or machine user opens agent PRs. Then add `CODEOWNERS` for the trust paths with `yaaf-some`, set `require_code_owner_review` and `require_last_push_approval`, and require 1 approval. GitHub then enforces what the gate only signals.
3. **Then:** allow agents to enable auto-merge on Tier 1 PRs only. Reword AGENTS.md Tier 1 and 3, and the `deny` rule in `.claude/settings.json`. Yaaf decides. A new yes is needed.

## Measure before widening
Track per month: auto-merged PRs, red `main` runs after an auto-merge, reverts, and PRs where `tier-gate` blocked auto-merge. Zero reds over 20 auto-merges is the bar to widen the allowlist. One red `main` after an auto-merge pauses auto-merge until the cause is fixed.
