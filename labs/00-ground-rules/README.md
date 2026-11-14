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
- AWS Budgets `runway-budget-5`, `-15`, `-30` (monthly, email at 100% of actual spend; the $30 one also at 100% of forecast) and a Cost Anomaly Detection monitor on AWS services with a daily email for anomalies of $1 or more (YAA-9). Code: [infra/](infra/). The alert address comes from the repo variable `ALERT_EMAIL`. _Not applied yet._
- ✅ Non-root IAM admin user `yaaf-admin` with MFA, signed in with `aws login --profile runway`; no long-lived keys (YAA-10). Checked 2026-11-14: caller ARN is `user/yaaf-admin`, `list-access-keys` is empty, `AccountAccessKeysPresent=0`, `AccountMFAEnabled=1`.
- GitHub OIDC → AWS role scoped to `main` (YAA-11)
- Remote state bucket, required tags, Terraform vs OpenTofu pick (YAA-12)
- `make nuke` + nightly reaper workflow (YAA-13)
- README with proof and cost receipt (YAA-14)

## Cost receipt
| Spent | Idle | Teardown |
|---|---|---|
| — | $0: budgets without actions and Anomaly Detection are free | `tofu destroy` of this stack; it is not ephemeral |

## Decisions
**Why not IAM Identity Center?** It grants access to AWS accounts only through an organization instance, and an account instance rejects permission sets. One account does not need an organization. An IAM user with MFA and `aws login` gives short-lived credentials without one.

**Why $5 / $15 / $30, and forecast only on $30?** Each step is a louder signal: $5 is the first sign a lab leaked, $15 means act today, $30 is the ceiling. An actual-spend alert fires after the money is spent. A forecast alert on the small budgets would fire on day 1 of a month, when AWS has little data. On the $30 budget it warns before the ceiling is hit.

**Why not an immediate anomaly alert?** AWS allows the IMMEDIATE frequency only for SNS subscribers. Email gets DAILY or WEEKLY. DAILY is the fastest email option. An SNS topic needs a topic policy for `costalerts.amazonaws.com` and a confirmed subscription: more moving parts than the alert is worth at this size. The $5 budget covers fast spikes.

## What broke
- The first sign-in was as **root**. Fixed in YAA-10.
- `sso-admin create-instance` is refused for an organization's management account.
- After deleting the organization, an account instance of Identity Center rejected `create-permission-set`: account instances can't grant access to AWS accounts. Dropped Identity Center.
- `tofu plan` found no credentials: the AWS provider (`~> 5.80`) didn't read the CLI login. Fix: `eval "$(aws configure export-credentials --format env)"`.

## What I'd change
_TBD._

**Target roles:** SA, Platform, Cloud, SRE, Security
