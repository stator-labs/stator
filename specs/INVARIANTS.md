---
title: Stator invariants
updated: 2026-11-24
---

# Stator invariants

These seven rules hold across every lab, platform module, automation workflow, and agent session.

## 1. Exception-based human gates

Machines clear low-risk work. Yaaf (the General) judges cost, blast radius, trust, and irreversible changes. See [AGENTS.md](../AGENTS.md) and [human-in-the-loop.md](../docs/human-in-the-loop.md).

### Live enforcement today

- `aws-apply` GitHub environment approval for AWS applies.
- `main` branch ruleset blocking direct pushes and requiring `Docs: lint`, `Infrastructure: required checks`, `Policy: trust paths`, and `Workflows: lint`.
- `Policy: trust paths` (`policy.yml`) blocking auto-merge outside the allow-list (`docs/` except `how-this-works.md`, `human-in-the-loop.md`, `index.md`, `radar.md`; `labs/*/README.md`; `templates/`; `README.md`).
- Agent hook guardrails ([guardrails.py](../.agents/hooks/guardrails.py)) denying PR merge/review and secret reads (`.env`, `*.key`, `*.auto.tfvars`), and prompting before `aws`, `tofu apply`, `tofu destroy`, or force pushes.
- CI linters: `tools/docs-lint.py`, `tools/specs-lint.py`, and [identifier-check.py](../tools/identifier-check.py).
- IAM boundaries (`stator-boundary`) and SCPs in `platform/infra/bootstrap/` and `platform/infra/foundation/`.
- Budgets (`$5`, `$15`, `$30`) and the `$30` kill-switch SCP in `platform/infra/foundation/`.

### Planned target-state automation

- Bot identity `stator-bot` for native `CODEOWNERS` and Merge Queue separation (bot identity `STAT-35`, `STAT-46`).
- `OPA/Conftest` plan gate and `Infracost` to auto-pass `$0`, non-destructive, non-IAM labs plans and route risky plans to Yaaf (OPA plan gate `STAT-34`).

### Tier 2 triggers (explicit approval required)

Stop and send a short risk ask using [stator-presenting](../.agents/skills/stator-presenting/SKILL.md) before acting on any of these triggers. One approval covers one exact change.

- **AWS:** applying a stack or approving a deployment.
- **Cost:** anything above `$0`, idle or per run.
- **Trust:** IAM, OIDC, rulesets, environments, secrets, tokens, network, or `.agents/hooks*`.
- **Deletion:** resources, data, issues, schedules, or unmerged branches.
- **Public:** comments on others' PRs, posts, or emails.
- **Scope:** work past **Done when**, more than `1` lab, more than about `300` changed lines, or repo-wide rules or pipelines.

## 2. Orwell plain English everywhere

Write short sentences in active voice with zero filler and zero em dashes across docs, specs, Linear issues, PRs, code comments, and chat replies. Follow [stator-writing](../.agents/skills/stator-writing/SKILL.md) and [stator-presenting](../.agents/skills/stator-presenting/SKILL.md). Never repeat empty fields such as `Cost: $0` or `Security: None`. `tools/docs-lint.py` enforces these rules in CI.

## 3. Zero static credentials or hardcoded IDs

Never commit AWS account IDs, static IAM keys, or personal emails to Git. [identifier-check.py](../tools/identifier-check.py) checks every PR. Keep personal values in git-ignored `foundation.auto.tfvars` and pass `-backend-config=bucket=$TF_STATE_BUCKET` in CI. GitHub Actions authenticates via OIDC; local terminal sessions use IAM Identity Center (`aws sso login --profile stator`).

## 4. Blast-radius and `$0` idle protection

Keep `prevent_destroy` on the AWS Organization, the `Labs` account (`close_on_deletion = false`), and the org CloudTrail bucket. Run budgets at `$5`, `$15`, and `$30`, with the `$30` kill-switch SCP (`runway-labs-deny-new-spend`) configured as an action-enabled budget under the 2 free action-enabled budgets. Tag every AWS resource (`project`, `lab`, `ephemeral` or `runway:ephemeral`, checked by Checkov) and pair every ephemeral stack with a teardown path and nightly reaper.

## 5. Proof-first lab completion

Never mark a lab complete without real AWS proof, a measured cost receipt, inline "Why not X?" decisions (2 to 3 sentences each), and "What broke" (keeping the first failure). Emulators (AWS Emulator, kind, k3d) are inner-loop tools only.

## 6. Verify before building (anti-assumption rule)

Probe CLI flags, connectors, API limits, and IAM condition keys against live tools or official documentation before writing implementation code or specs. Record verified values and limits directly in `specs/` or the lab README.

## 7. Policy-as-code over prose

Enforce `AGENTS.md` and Tier 0 to Tier 3 mechanically rather than relying on prompts. Use CI linters, `tofu test` mutation checks, full-SHA GitHub Action pinning, image digest pinning, hook deny lists in [guardrails.py](../.agents/hooks/guardrails.py), and `stator-bot`.

## Five-stage zero-trust automation pipeline

Scheduled and event-driven automation isolates untrusted input from write credentials across five stages (see [how-this-works.md](../docs/how-this-works.md)):

1. **Trigger:** cron schedule, Cloudflare Worker webhook (`repository_dispatch`), or `workflow_dispatch`.
2. **Collect:** deterministic script fetches JSON state and sanitizes untrusted web or issue text.
3. **Reason:** bounded, stateless LLM (`gh-aw`) runs on a pinned model with zero write tokens behind an egress wall.
4. **Gate:** deterministic checks run secret/threat scans, IAM/SCP lint, `tofu test`, Checkov, Zizmor, `docs-lint`, and Safe Outputs JSON schema validation.
5. **Act:** scoped write step opens a PR (`stator-bot`) or updates Linear; Yaaf approves merges and `aws-apply`.

## Session and AWS access rules

### Model routing

- Route flagship models to multi-file OpenTofu, OIDC/SCP/IAM policy design, threat modeling, and subtle bugs.
- Route fast models to lint fixes, documentation edits, and summaries.
- Pin explicit model IDs in scheduled and event-driven automation.

### AWS credentials and stack boundaries

- **Never put AWS credentials in an agent session** (Tier 3 rule). Agents write OpenTofu; GitHub Actions runs `tofu plan` on PRs and `tofu apply` after merge and `aws-apply` approval.
- **Terminal-only bootstrap stacks:** `platform/infra/bootstrap/` and `platform/infra/labs-bootstrap/` always run from Yaaf's terminal using Identity Center SSO because they create state buckets, OIDC providers, and CI roles.
- **Foundation transition state:** `platform/infra/foundation/` currently sits in `TERMINAL_ONLY` in [tofu-stacks.py](../tools/tofu-stacks.py) and [platform/infra/README.md](../platform/infra/README.md), so CI lints it without planning or applying. Meanwhile, [foundation-ci.tf](../platform/infra/bootstrap/foundation-ci.tf) already defines its target-state CI roles: `stator-foundation-plan` (read-only plus foundation state read and `.tflock` write) and `stator-foundation-apply` (bound to `aws-foundation-apply`, zero `PowerUserAccess`, writes scoped to 7 foundation services plus explicit S3/SNS/Events/IAM kill-switch ARNs, and explicit denies on org deletion, CloudTrail erasure, bucket destruction, and pipeline/OIDC escalation). Keep `platform/infra/foundation/` in `TERMINAL_ONLY` until `.github/workflows/infrastructure.yml` wires that lane.
