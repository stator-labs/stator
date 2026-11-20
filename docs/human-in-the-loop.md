---
title: Human in the loop
updated: 2026-11-20
---

# Human in the loop

Agents do the work. Yaaf decides what is risky, costly or hard to undo. Everything else should not need him.

The aim is **few, informed decisions**, not many rubber stamps. An approval Yaaf can't judge in a minute is a bad approval request, not a careful one.

This page says **why** and **what enforces it**. The rules are in [AGENTS.md](../AGENTS.md#human-in-the-loop). The change card format is in the [`runway-presenting`](../.claude/skills/runway-presenting/SKILL.md) skill.

## Why it works this way
1. **Gate by consequence, not by effort.** Blast radius, reversibility, cost and trust decide the tier, not how much work a change took. A 5-line IAM change is Tier 2; a 200-line README is Tier 1.
2. **Enforce in tools, not just in prompts.** A rule an agent can skip is a hope. So the gates below live in GitHub, IAM and Claude Code settings, and prompts only explain them.
3. **Show what will happen, then ask.** Yaaf approves what he sees: the plan, the cost, the diff, the rollback. A card without them can't be judged.
4. **One approval, one exact change.** A yes on one plan says nothing about the next commit, plan or target.
5. **Silence means no.** A timeout that proceeds turns every unread message into an approval.

## What enforces it
| Gate | Covers | Where | State |
|---|---|---|---|
| `aws-apply` environment approval | every AWS change | GitHub environment; the apply role trusts only that environment | live |
| `main` ruleset | no direct pushes; `Docs: lint`, `Infrastructure: required checks`, `Policy: trust paths` and `Workflows: lint` must pass; branches must be up to date | GitHub ruleset | live |
| `Infrastructure: required checks` | a PR that breaks `Infrastructure: validate` or `Infrastructure: plan` cannot merge; reports on every PR | `infrastructure.yml` | live |
| `Policy: trust paths` | auto-merge on a PR that changes any file outside the allow-list in AGENTS.md (default deny); Yaaf's own Merge still works | `policy.yml`, run from `main` (`pull_request_target`), reads file names only, never PR code | live |
| `Workflows: lint` | unpinned actions, template injection, over-broad permissions and dangerous triggers (zizmor); syntax, expression and shell-script errors (actionlint with shellcheck) in any workflow | `workflows.yml` | live |
| Dependabot | pinned actions going stale; releases younger than 7 days are skipped | `.github/dependabot.yml`; every bump is a human-merged PR | live |
| Up-to-date branches | a PR that is green alone but stale against `main` cannot merge. A merge queue needs an organization-owned repo, so this repo uses the ruleset's up-to-date setting. The workflows already run on `merge_group`, so a move to an organization needs no workflow change | ruleset | live |
| Checks on `main` | `Docs: lint` and `Infrastructure: validate` re-run on every push to `main`; `Infrastructure: apply` waits for `validate` | `docs.yml`, `infrastructure.yml` | live |
| Plan comment | what an apply will do, before merge | `infrastructure.yml` | live; risk summary and cost planned |
| Claude Code `ask` / `deny` rules | agents never approve, review or merge a PR (deny: they act as Yaaf on GitHub, so their approval would count as his); force pushes, `tofu apply`/`destroy`, AWS CLI, scheduled tasks, environments; reading key files | `.claude/settings.json` | live |
| `CODEOWNERS` | marks the trust paths as Yaaf's. Not a required review: agent PRs are authored as Yaaf, and GitHub doesn't let an author approve their own PR. It takes effect if agents ever get their own GitHub identity (RUN-32) | `.github/CODEOWNERS` | live |
| PR template | the change card fields on every PR | `.github/pull_request_template.md` | live |
| Style check | stock phrases, em dashes | `tools/docs-lint.py` | live |
| Permission boundary and IAM path | roles that agents' code can create | `platform/infra/bootstrap/iam.tf` | live |
| Budgets and anomaly alerts | cost that slips through anyway | Lab 00 stack | live |

## Sources
- Anthropic, [framework for safe and trustworthy agents](https://www.anthropic.com/news/our-framework-for-developing-safe-and-trustworthy-agents): human control before high-stakes actions, plan-level approval, transparency.
- OWASP, [Top 10 for Agentic Applications](https://genai.owasp.org/2025/12/09/owasp-top-10-for-agentic-applications-the-benchmark-for-agent): least agency; human approval for irreversible and goal-changing actions.
- Tiering, approval content and fatigue: [Obsidian Security](https://www.obsidiansecurity.com/academy/human-in-the-loop-agent-approvals), [Tian Pan on gate placement](https://tianpan.co/blog/2026/04/17/hitl-placement-theory-approval-gates) and [undrained approval queues](https://tianpan.co/blog/2026/05/17/approval-queue-nobody-drains), [the HITL paradox](https://dev.to/sks/the-hitl-paradox-when-human-approval-makes-agents-worse-1095).
- Plan policy: [OPA Terraform guide](https://openpolicyagent.org/docs/terraform), [Atlantis policy checking](https://www.runatlantis.io/docs/policy-checking). Cost in PRs: [Infracost GitHub Actions](https://www.infracost.io/docs/integrations/github_actions/).
