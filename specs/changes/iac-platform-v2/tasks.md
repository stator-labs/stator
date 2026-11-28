# IaC platform v2: tasks

Tier legend: **T1** a PR Yaaf merges. **T2** Yaaf approves and, where stated, applies or changes a setting. Agents never apply terminal stacks or hold AWS credentials. One PR per task unless noted.

## 1. Stop approve-before-plan applies
- **Context manifest:**
  - `.github/workflows/infrastructure.yml`
- **Change:** set the old apply job to `if: false` until task 8. Tier T1.
- **Verify:** a push to `main` that touches `tools/` creates no waiting `aws-apply` run.
- **Done when:** merged and one push to `main` shows the apply job skipped.

## 2. Agent merge guard (before any auto lane)
- **Context manifest:**
  - `.agents/hooks.json`
  - `.agents/hooks/guardrails.py`
  - `.claude/settings.json`
- **Change:** wire the guard for Claude Code. Deny `gh pr merge` (except `--auto`) and any `pending_deployments` call. Tier T2 (`.agents/hooks*`).
- **Verify:** the hook self-test denies both calls from a Claude Code session.
- **Done when:** merged; until then and until `stator-bot` (STAT-46), `aws-apply-auto` is not created.

## 3. Delete management CI roles
- **Context manifest:**
  - `platform/infra/bootstrap/iam.tf`
  - `platform/infra/bootstrap/main.tf`
  - `platform/infra/bootstrap/foundation-ci.tf`
  - `platform/infra/bootstrap/outputs.tf`
  - `platform/infra/bootstrap/bootstrap.sh`
  - `platform/infra/bootstrap/tests/bootstrap.tftest.hcl`
  - `platform/infra/foundation/import-budgets.sh`
- **Change:** remove `runway-plan`, `runway-apply`, `runway-apply-iam`, `runway-boundary`, `runway-reaper`, `stator-foundation-*`, the management OIDC provider and every GitHub write in `bootstrap.sh`. Keep `runway-budget-kill-switch`. Tier T2 (IAM, OIDC, deletion); Yaaf runs `make plan` then applies.
- **Verify:** `make plan` shows destroys only. Afterwards `/runway/` lists only `runway-budget-kill-switch` and management has 0 OIDC providers.
- **Done when:** applied and verified.

## 4. Delete dead GitHub settings
- **Context manifest:**
  - `.github/workflows/tofu-plan.yml`
- **Change:** remove `OIDC_SUB_PREFIX`, `AWS_FOUNDATION_*`, secret `ALERT_EMAIL` (and its declaration), env `aws-foundation-apply`. Tier T2; Yaaf runs `gh`.
- **Verify:** `gh variable list` and `gh secret list` show no dead names.
- **Done when:** lists are clean.

## 5. Scratch-repo test
- **Context manifest:**
  - `specs/changes/iac-platform-v2/proposal.md`
- **Change:** test whether a job waiting on a reviewer holds the concurrency slot, and whether "Require SHA pinning" rejects a `@main` reusable call. Tier T2 (Yaaf creates the repo).
- **Verify:** written answers recorded in the proposal's open questions.
- **Done when:** both questions answered.

## 6. Labs roles v2
- **Context manifest:**
  - `platform/infra/modules/ci-roles/`
  - `platform/infra/labs-bootstrap/iam.tf`
  - `platform/infra/labs-bootstrap/main.tf`
  - `platform/infra/labs-bootstrap/outputs.tf`
  - `platform/infra/labs-bootstrap/bootstrap.sh`
  - `platform/infra/labs-bootstrap/tests/labs-bootstrap.tftest.hcl`
- **Change:** `ci-roles` module with 4 presets on `/stator/platform/`, side by side with the old roles. Remove `stator-plan-main`. `cutover` writes only `AWS_LABS_ACCOUNT_ID`. Tier T2 (IAM, OIDC); Yaaf applies.
- **Verify:** `tofu test` has a run per preset and per deny; `make plan` creates only the new roles and policies, 0 destroys.
- **Done when:** applied; PR plans still work on the old roles.

## 7. Stack map and gate fixes
- **Context manifest:**
  - `platform/stacks.toml`
  - `tools/tofu-stacks.py`
  - `tools/plan-gate.py`
  - `tools/provider-allowlist.py`
- **Change:** one config file read from `main`; gate accepts only `stator-boundary`, checks `NotAction`, sends unknown policy to manual. Tier T1.
- **Verify:** self-tests green with new cases.
- **Done when:** merged; next PR shows the same lanes for unchanged stacks.

## 8. Pipeline v2 (rework of PR #38)
- **Context manifest:**
  - `.github/workflows/infrastructure.yml`
  - `.github/workflows/plan.yml`
  - `.github/workflows/apply.yml`
  - `.github/workflows/supersede.yml`
  - `tools/apply-alert.sh`
- **Change:** plan-all on `main`, saved plans, `apply.yml` with HEAD guard and gate re-run, Supersede, rolling "apply waiting" issue, fail-fast variables, v2 roles. Turn admin bypass off on `aws-apply`. Tier T2 (pipeline, environments).
- **Verify:** first plan-all shows 0 changes for Lab 00's 11 resources; two quick manual merges leave one waiting run; rerunning an old apply exits "superseded".
- **Done when:** all five checks in the proposal's Pipeline section observed.

## 9. Delete old labs roles
- **Context manifest:**
  - `platform/infra/labs-bootstrap/iam.tf`
  - `platform/infra/labs-bootstrap/main.tf`
- **Change:** remove `stator-plan`, `stator-apply`, `stator-apply-iam`, `stator-reaper` on `/stator/` and old variables. Tier T2.
- **Verify:** `make plan` destroys only those; one full PR, merge and apply cycle is green.
- **Done when:** `gh variable list` shows only `AWS_LABS_ACCOUNT_ID` and `AWS_REGION`.

## 10. One tag set
- **Context manifest:**
  - `labs/00-account-foundation/infra/versions.tf`
  - `platform/infra/bootstrap/versions.tf`
  - `platform/infra/foundation/versions.tf`
  - `platform/infra/labs-bootstrap/versions.tf`
  - `tools/checkov/runway_default_tags.py`
  - `tools/reaper.py`
  - `.github/workflows/reaper.yml`
- **Change:** `project`, `lab`, `stack`, `ephemeral` everywhere; `CKV_STATOR_1`; rename `runway` identifiers in pipeline code. Tier T2.
- **Verify:** `grep -rn "runway:" platform labs tools .github` returns 0.
- **Done when:** applied in every stack.

## 11. Org guardrails
- **Context manifest:**
  - `platform/infra/foundation/guardrails.tf`
  - `platform/infra/foundation/tests/foundation.tftest.hcl`
- **Change:** `stator-protect-platform` SCP, S3 RCP, EC2 declarative policy, tag policy with `tag_policy_compliance = "error"`. Verify SCP action names first. Tier T2; Yaaf applies.
- **Verify:** probe role under `/stator/platform/` gets an explicit SCP deny; a resource without `stack` fails at plan.
- **Done when:** a normal PR, merge and apply cycle is green afterwards.

## 12. Check hardening and Drift
- **Context manifest:**
  - `.github/workflows/workflows.yml`
  - `.github/workflows/drift.yml`
  - `tools/cloud-setup.sh`
- **Change:** shellcheck, CLI `provider_installation`, `ValidatePolicy`, Drift workflow; native SHA pinning and lockfile settings if task 5 allows. Tier T1, settings T2.
- **Verify:** a dispatch Drift run on clean `main` opens no issue.
- **Done when:** merged and settings recorded.

## 13. Remove `runway` names
Task 10 covers tags, the checkov ID and pipeline code. This task renames everything else to `stator-*`, cheapest first. Each AWS step plans first and keeps the old resource until the new one works.
- **Context manifest:**
  - `platform/infra/foundation/organization.tf`
  - `platform/infra/foundation/identity-center.tf`
  - `platform/infra/foundation/guardrails.tf`
  - `platform/infra/foundation/kill-switch.tf`
  - `platform/infra/foundation/budgets.tf`
  - `platform/infra/foundation/trail.tf`
  - `platform/infra/foundation/tests/foundation.tftest.hcl`
  - `platform/infra/bootstrap/main.tf`
  - `platform/infra/README.md`
- **Change:**
  1. Code only: docs, specs, the research report filename, the plan comment marker. Tier T1.
  2. In place: SCP names and the `runway-labs` account name. Check first that the provider updates each one without replacing it. Tier T2.
  3. Create, switch, delete: `runway-budget-kill-switch` role, budgets, anomaly monitor and root sign-in alert (`anomaly.tf`, `alerts.tf`), `runway-org-external-access` analyzer. Tier T2.
  4. `runway-admin` permission set: create `stator-admin` next to it, sign in with it, point `sso_role_name` in `~/.aws/config` at it, then remove the old one. Never both gone at once. Tier T2.
  5. Data moves: new `stator-tfstate-<management id>` bucket, `tofu init -migrate-state` for `bootstrap` and `foundation`, old bucket kept until both stacks plan clean. New trail and log bucket; the old log bucket stays until its 90-day retention ends, then goes. Tier T2.
- **Verify:** `git grep -i runway -- . ':!specs/changes'` returns only dated "What broke" history; `aws iam list-roles --path-prefix /runway/` and `aws organizations list-policies --filter SERVICE_CONTROL_POLICY` show no `runway-*` names.
- **Done when:** no `runway-*` resource remains in either account except the old trail log bucket, with its delete date recorded in the Lab 00 README.

## 14. Docs, specs and cleanup
- **Context manifest:**
  - `platform/infra/README.md`
  - `specs/STACK.md`
  - `specs/INVARIANTS.md`
  - `docs/human-in-the-loop.md`
- **Change:** merge the deltas, close the 23 doc mismatches, delete this folder. Optional: move the Lab 00 state key to `lab00/`. Tier T1.
- **Verify:** docs-lint and specs-lint pass.
- **Done when:** `specs/changes/iac-platform-v2/` is deleted.
