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

# Lab 00 · Ground Rules

**Proof** (checked in GitHub Actions on 2026-11-19; no AWS access needed):
- **Plan comment on a PR:** [PR #13, `tofu plan`: 2 to add, 0 to change, 0 to destroy](https://github.com/yaaf-some/cloud-project/pull/13#issuecomment-7017659792).
- **Approved apply:** [run 44585735716](https://github.com/yaaf-some/cloud-project/actions/runs/44585735716), the merge of PR #13. The job signed in to `runway-apply` with OIDC. The `aws-apply` deployment waited from 18:15 to 18:27 UTC until Yaaf approved it. Then the apply ended with `Apply complete! Resources: 2 added, 0 changed, 0 destroyed.` The two resources are the anomaly monitor `runway-account` and the subscription `runway-anomaly-email`.
- **Budgets:** `runway-budget-5`, `-15` and `-30` were created by [the merge run of PR #9, first attempt](https://github.com/yaaf-some/cloud-project/actions/runs/44581039403/attempts/1). The log shows `Creation complete` for each. The same run then failed on the monitor (see What broke).
- **Not proven yet:** the reaper and `make nuke` (YAA-13). Lab 00 stays 🔨 until they ship.

## Problem
Nobody knows what the AWS account costs, keys live in laptops, and nothing can be torn down with confidence. Before any lab touches AWS, the account needs a safety net: budgets, no static keys, remote state and a one-command teardown.

## What I built
- Three monthly AWS Budgets: `runway-budget-5`, `-15` and `-30`. Each emails at 100% of actual spend. The $30 one also emails at 100% of forecast (YAA-9). A Cost Anomaly Detection monitor watches the whole account and sends a daily email for anomalies of $1 or more. ✅ Budgets and monitor are applied. Code: [infra/](infra/). The alert address comes from the Actions secret `ALERT_EMAIL`.
- ✅ Non-root IAM admin user `yaaf-admin` with MFA, signed in with `aws login --profile runway`; no long-lived keys (YAA-10). Checked 2026-11-14: caller ARN is `user/yaaf-admin`, `list-access-keys` is empty, `AccountAccessKeysPresent=0`, `AccountMFAEnabled=1`.
- OpenTofu pipeline (YAA-11; YAA-12 was merged into it): `make bootstrap` creates the state bucket `runway-tfstate-<account>`, the GitHub OIDC provider, `runway-plan` (PRs, read-only) and `runway-apply` (environment `aws-apply`, `main` only). PRs get `tofu plan` as a comment; merges apply after approval. CI fails any AWS provider without `default_tags` `project`, `lab`, `runway:ephemeral`. Code: [platform/infra](../../platform/infra/README.md). ✅ Ran end to end: see Proof.
- Not built yet: `make nuke` and the nightly reaper workflow (YAA-13)
- ✅ README with proof and cost receipt (YAA-14)

## Cost receipt
| Spent | Idle | Teardown |
|---|---|---|
| $0, no usage billed yet (as of 2026-11-19) | $0: budgets without actions and Anomaly Detection are free | `tofu destroy` of this stack; it is not ephemeral |

## Decisions
**Why not Terraform?** OpenTofu, picked on Nov 13. It is open source (MPL 2.0) under the Linux Foundation; Terraform moved to the BSL. It has the S3 lockfile, which removes the DynamoDB lock table. The CLI and the AWS provider are the same, so the skills carry over.

**Why not a narrower apply role?** Labs will create Lambda, EKS, VPCs, Bedrock access and more; a hand-written allowlist would break on every new lab. So the apply role is PowerUserAccess, plus IAM writes only under `/runway/`, and only for roles that carry the `runway-boundary` permissions boundary. Explicit denies stop it from touching its own role and policy, the plan role, the boundary, the OIDC provider and the state bucket settings. Narrowing per lab is a later step, once the labs show what they need.

**Why an approval gate?** The `main` ruleset requires a PR and a green `kb-check`, but 0 approvals: Yaaf works alone, and agents open the PRs. So a merge alone must not change AWS. The `aws-apply` environment needs Yaaf's approval and only accepts `main`, and the apply role trusts only that environment. That approval is the one hard gate before real changes.

**Why trust the ID-based subject?** GitHub issues the OIDC `sub` claim in the form `repo:<owner>@<owner id>/<repo>@<repo id>:<context>`, and the roles trust exactly that. IDs never change when a repo is renamed, and a repo re-created under the same name gets a new ID, so nobody else can take over the name and assume the role. `bootstrap.sh` reads the prefix from `gh api repos/<repo>/actions/oidc/customization/sub` instead of rebuilding it from the repo name.

**Why not IAM Identity Center?** It grants access to AWS accounts only through an organization instance, and an account instance rejects permission sets. One account does not need an organization. An IAM user with MFA and `aws login` gives short-lived credentials without one.

**Why $5 / $15 / $30, and forecast only on $30?** Each step is a louder signal: $5 is the first sign a lab leaked, $15 means act today, $30 is the ceiling. An actual-spend alert fires after the money is spent. A forecast alert on the small budgets would fire on day 1 of a month, when AWS has little data. On the $30 budget it warns before the ceiling is hit.

**Why our own account monitor, not the default AWS services one?** AWS allows one "AWS services" monitor per account and creates it itself (`Default-Services-Monitor`), so a second one is refused. Adopting it would need its random ARN passed into the stack through a secret and a workflow change, and the stack would depend on a resource AWS owns. A custom monitor on the account needs neither. It reports anomalies for the whole account, with the services that caused each one listed in the alert. It does not score each service on its own.

**Why not an immediate anomaly alert?** AWS allows the IMMEDIATE frequency only for SNS subscribers. Email gets DAILY or WEEKLY. DAILY is the fastest email option. An SNS topic needs a topic policy for `costalerts.amazonaws.com` and a confirmed subscription: more moving parts than the alert is worth at this size. The $5 budget covers fast spikes.

## What broke
- The first sign-in was as **root**. Fixed in YAA-10.
- `sso-admin create-instance` is refused for an organization's management account.
- After deleting the organization, an account instance of Identity Center rejected `create-permission-set`: account instances can't grant access to AWS accounts. Dropped Identity Center.
- The first apply created the 3 budgets, then failed on the anomaly monitor ([run log](https://github.com/yaaf-some/cloud-project/actions/runs/44581039403/attempts/1)). A rerun of the same run failed the same way: `Limit exceeded on dimensional spend monitor creation`. The account already had AWS's default services monitor (`aws ce get-anomaly-monitors` showed it). Fix: our own account-level monitor.
- The first `tofu plan` in CI failed with "Not authorized to perform sts:AssumeRoleWithWebIdentity". The roles trusted `repo:yaaf-some/cloud-project:pull_request`, but this repo has immutable OIDC subjects, so the token's `sub` carries the owner and repo IDs. The trust policy had matched the code and the code was wrong; nothing in AWS showed the real value. Fix: trust the subject prefix GitHub reports, and print the token's claims (`tools/oidc-claims.py`) whenever sign-in fails.
- `tofu plan` found no credentials: the AWS provider (`~> 5.80`) didn't read the CLI login. Fix: `eval "$(aws configure export-credentials --format env)"`. `make bootstrap` does this for you (YAA-11).
- Three stray budgets from an earlier manual attempt (`runway-monthly-5usd`, `-15usd`, `-30usd`) doubled the budget list. Yaaf deleted them by hand on Nov 19. The pipeline's `runway-budget-*` stayed.
- The `aws-apply` run for PR #8 stayed in "waiting" for five days. Yaaf had to reject it by hand on Nov 19 (it shows as cancelled).
- The IAM admin user could not open Cost Explorer or billing pages at first. It needed a one-time root step to allow IAM user access to billing and Cost Explorer ([AWS docs](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/control-access-billing.html)). Yaaf got it working on Nov 19.

## What I'd change
- Grant billing and Cost Explorer access, and delete stale manual resources, before the first apply.
- Run `aws ce get-anomaly-monitors` before writing the monitor. It lists the account's default monitor, which is why a second services monitor is refused.
- Cancel or reject a waiting `aws-apply` run when its PR is superseded, so it does not sit for days.

**Target roles:** SA, Platform, Cloud, SRE, Security
