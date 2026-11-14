---
lab: "00"
title: "Ground Rules"
status: now
effort: "1 weekend"
cost_estimate: "~$0"
cost_spent: 0
roles: [SA, Platform, Cloud, SRE, Security]
linear: "P-YAA-2"
---

# Lab 00 — Ground Rules

**Proof:** _not yet_

## Problem
Nobody knows what the AWS account costs, keys live in laptops, and nothing can be torn down with confidence. Before any lab touches AWS, the account needs a safety net: budgets, no static keys, remote state and a one-command teardown.

## What I built
_Planned:_
- AWS Budgets at $5 / $15 / $30 + Cost Anomaly Detection (YAA-9)
- ✅ Non-root IAM admin user `yaaf-admin` with MFA, signed in with `aws login --profile runway`; no long-lived keys (YAA-10). Checked 2026-11-14: caller ARN is `user/yaaf-admin`, `list-access-keys` is empty, `AccountAccessKeysPresent=0`, `AccountMFAEnabled=1`.
- OpenTofu pipeline (YAA-11; YAA-12 was merged into it): `make bootstrap` creates the state bucket `runway-tfstate-<account>`, the GitHub OIDC provider, `runway-plan` (PRs, read-only) and `runway-apply` (environment `aws-apply`, `main` only). PRs get `tofu plan` as a comment; merges apply after approval. CI fails any AWS provider without `default_tags` `project`, `lab`, `runway:ephemeral`. Code: [platform/infra](../../platform/infra/README.md). _Not run yet._
- `make nuke` + nightly reaper workflow (YAA-13)
- README with proof and cost receipt (YAA-14)

## Cost receipt
| Spent | Idle | Teardown |
|---|---|---|
| — | — | — |

## Decisions
**Why not Terraform?** OpenTofu, picked on Nov 13. It is open source (MPL 2.0) under the Linux Foundation; Terraform moved to the BSL. It has the S3 lockfile, which removes the DynamoDB lock table. The CLI and the AWS provider are the same, so the skills carry over.

**Why not a narrower apply role?** Labs will create Lambda, EKS, VPCs, Bedrock access and more; a hand-written allowlist would break on every new lab. So the apply role is PowerUserAccess, plus IAM writes only under `/runway/`, and only for roles that carry the `runway-boundary` permissions boundary. Explicit denies stop it from touching its own role and policy, the plan role, the boundary, the OIDC provider and the state bucket settings. Narrowing per lab is a later step, once the labs show what they need.

**Why an approval gate?** The `main` ruleset requires a PR and a green `kb-check`, but 0 approvals: Yaaf works alone, and agents open the PRs. So a merge alone must not change AWS. The `aws-apply` environment needs Yaaf's approval and only accepts `main`, and the apply role trusts only that environment. That approval is the one hard gate before real changes.

**Why not IAM Identity Center?** It grants access to AWS accounts only through an organization instance, and an account instance rejects permission sets. One account does not need an organization. An IAM user with MFA and `aws login` gives short-lived credentials without one.

## What broke
- The first sign-in was as **root**. Fixed in YAA-10.
- `sso-admin create-instance` is refused for an organization's management account.
- After deleting the organization, an account instance of Identity Center rejected `create-permission-set`: account instances can't grant access to AWS accounts. Dropped Identity Center.
- `tofu plan` found no credentials: the AWS provider (`~> 5.80`) didn't read the CLI login. Fix: `eval "$(aws configure export-credentials --format env)"`. `make bootstrap` does this for you (YAA-11).

## What I'd change
_TBD._

**Target roles:** SA, Platform, Cloud, SRE, Security
