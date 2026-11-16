---
title: Human in the loop
updated: 2026-11-16
---

# Human in the loop

Agents do the work. Yaaf decides what is risky, costly or hard to undo. Everything else should not need him.

The aim is **few, informed decisions**, not many rubber stamps. An approval Yaaf can't judge in a minute is a bad approval request, not a careful one.

## Principles
1. **Gate by consequence, not by effort.** What matters is blast radius, reversibility, cost and trust, not how much work it took.
2. **Enforce in tools, not just in prompts.** A rule an agent can skip is a hope. Approval gates live in GitHub environments, rulesets, IAM trust and Claude Code permission rules; this page says why.
3. **Show what will happen, then ask.** Every request carries the evidence: the plan, the cost, the diff, the rollback. Yaaf approves what he sees.
4. **An approval covers one exact change.** New commits, a different plan or a different target mean a new approval.
5. **Silence means no.** Nothing waits on a timeout and then proceeds.
6. **Ask once.** A standing decision is recorded in Linear and is not asked again (for example "network access is Full").
7. **Tiers move with evidence.** Weekly board health counts approvals. A category approved unchanged for a month can move down a tier; anything that went wrong moves up.

## The four tiers
| Tier | What | Examples | How Yaaf sees it |
|---|---|---|---|
| **0 · Do** | Reversible, private, free | read code, research, edit on a branch, run checks, draft PRs, Linear comments and status | Linear handoff and the PR. No interruption |
| **1 · Review** | Changes the repo, nothing else | code, docs, workflows, new tools, small fixes | A PR he reviews and merges himself. Agents never merge |
| **2 · Ask first** | Real-world effect, cost, trust or scale | anything below | A **change card**. The agent stops until Yaaf says yes |
| **3 · Never** | Agents don't do it at all | AWS keys in a session, root, running `make bootstrap`, disabling a guardrail, force-push to `main`, approving its own deployment | n/a |

**Tier 2 triggers.** Any one is enough:
- **AWS changes:** applying a stack, or approving a deployment.
- **Cost:** any non-zero cost, including idle cost and anything metered per run.
- **Trust and access:** IAM, OIDC trust, permission boundaries, GitHub rulesets, environments, secrets, tokens, network settings, connectors.
- **Deletion:** resources, data, issues, scheduled tasks, or branches with unmerged work.
- **Outside visibility:** comments on someone else's PR, public posts, publishing pages, emails.
- **Scale:** more than about 300 changed lines, more than one lab, or a change to a project-wide convention (AGENTS.md, this page, the pipeline, the setup script).
- **Doubt:** the agent isn't sure which tier applies.

## The change card
One card per decision, not per step. It must fit on one screen.

```markdown
### <What> — Tier 2: <trigger>
**Why:** one sentence.
**What changes:** table of resource or file · add / change / destroy · note.
**Picture:** Mermaid diagram when trust, data flow or architecture changes.
**Cost:** one-time · monthly · idle, with the source (Infracost or the AWS pricing page). "$0" needs a reason.
**Risk:** what breaks if this is wrong, and who notices.
**Security:** permissions or trust added or widened. "None" is a valid answer.
**Rollback:** exact steps, and whether it is fully reversible.
**Checked / not checked:** what was verified, and what only real AWS will show.
**Decision:** approve · change · decline. Recommended: <one>. No answer = nothing happens.
```

Where it appears:
- **AWS changes:** the plan comment on the PR, then the `aws-apply` approval in GitHub.
- **Repo-wide changes:** the PR description, using the PR template.
- **Everything else:** the agent's message in the session, plus a comment on the Linear issue.

## What enforces it
| Gate | Covers | Where |
|---|---|---|
| `aws-apply` environment approval | every AWS change | GitHub environment; the apply role trusts only that environment |
| `main` ruleset | no direct pushes, required `kb-check` | GitHub ruleset |
| Plan comment with risk summary and cost | what an apply will do, before merge | `tofu.yml` |
| Claude Code `ask` rules | merges, force pushes, `tofu apply`/`destroy`, AWS CLI, deleting scheduled tasks | `.claude/settings.json` |
| Permission boundary and IAM path | roles agents' code can create | `platform/infra/bootstrap/iam.tf` |
| Budgets and anomaly alerts | cost that slips through anyway | Lab 00 stack |

## Interruptions
- **Push notification:** only a Tier 2 card, or a failure that blocks work.
- **Batched:** everything else goes in the Linear handoff, the PR, and the weekly board-health update.
- **Bundled:** one message holds all open decisions, each with a recommended answer.
- **Stale:** an unanswered card is re-raised once in the next board-health update, then dropped.

## Sources
- Anthropic, [framework for safe and trustworthy agents](https://www.anthropic.com/news/our-framework-for-developing-safe-and-trustworthy-agents): human control before high-stakes actions, plan-level approval, transparency.
- OWASP, [Top 10 for Agentic Applications](https://genai.owasp.org/2025/12/09/owasp-top-10-for-agentic-applications-the-benchmark-for-agent): least agency; human approval for irreversible and goal-changing actions.
- Tiering, approval content and fatigue: [Obsidian Security](https://www.obsidiansecurity.com/academy/human-in-the-loop-agent-approvals), [Tian Pan on gate placement](https://tianpan.co/blog/2026/04/17/hitl-placement-theory-approval-gates) and [undrained approval queues](https://tianpan.co/blog/2026/05/17/approval-queue-nobody-drains), [the HITL paradox](https://dev.to/sks/the-hitl-paradox-when-human-approval-makes-agents-worse-1095).
- Plan policy: [OPA Terraform guide](https://openpolicyagent.org/docs/terraform), [Atlantis policy checking](https://www.runatlantis.io/docs/policy-checking). Cost in PRs: [Infracost GitHub Actions](https://www.infracost.io/docs/integrations/github_actions/).
