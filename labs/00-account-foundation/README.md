---
lab: "00"
title: "Account Foundation"
status: now
effort: "1 weekend"
cost_estimate: "~$0"
cost_spent: 0
roles: [SA, Platform, Cloud, SRE, Security]
---

# Lab 00 · Account Foundation

**Proof** (checked in GitHub Actions on 2026-11-19; no AWS access needed):
- **Plan comment on a PR:** [PR #13, `tofu plan`: 2 to add, 0 to change, 0 to destroy](https://github.com/yaaf-some/cloud-project/pull/13#issuecomment-7017659792).
- **Approved apply:** [run 44585735716](https://github.com/yaaf-some/cloud-project/actions/runs/44585735716), the merge of PR #13. The job signed in to `runway-apply` with OIDC. The `aws-apply` deployment waited from 18:15 to 18:27 UTC until Yaaf approved it. Then the apply ended with `Apply complete! Resources: 2 added, 0 changed, 0 destroyed.` The two resources are the anomaly monitor `runway-account` and the subscription `runway-anomaly-email`.
- **Budgets:** `runway-budget-5`, `-15` and `-30` were created by [the merge run of PR #9, first attempt](https://github.com/yaaf-some/cloud-project/actions/runs/44581039403/attempts/1). The log shows `Creation complete` for each. The same run then failed on the monitor (see What broke).
- **Reaper applied:** [run 44703993484](https://github.com/yaaf-some/cloud-project/actions/runs/44703993484) on 2026-11-20 created `runway-reaper` and its policy: `Apply complete! Resources: 2 added, 0 changed, 0 destroyed.` The `aws-apply` deployment waited for Yaaf's approval.
- **First reaper dry run:** [run 44704490487](https://github.com/yaaf-some/cloud-project/actions/runs/44704490487), started by hand from `main` on 2026-11-20. The job signed in as `runway-reaper` with OIDC, and the tagging query step passed. No ephemeral resource exists yet, so the report is expected to be empty; the summary page was not read when this was written.
- **Organization guardrails:** on 2026-11-20 Yaaf applied [platform/infra/foundation](../../platform/infra/foundation/) from his terminal: `Apply complete! Resources: 1 imported, 24 added, 1 changed, 0 destroyed.` Then, from the labs account as `OrganizationAccountAccessRole`: `ec2 describe-instances` in `us-west-2` returned an empty list; the same call in `eu-west-1` and `iam put-account-properties RoleManager/Enabled=true` both failed with `explicit deny in a service control policy`. The instance-type and commitment statements are not tested yet.
- **Tests without AWS access:** `tofu test` runs [6 tests for this stack](infra/tests/account-foundation.tftest.hcl) and [11 for the foundation stack](../../platform/infra/foundation/tests/foundation.tftest.hcl) against a mocked AWS provider, on 2026-11-21 in a cloud session with no credentials: `Success! 6 passed, 0 failed.` and `Success! 11 passed, 0 failed.` They check the plan, not AWS: three budgets with the forecast alert on the $30 one only, the daily $1 anomaly alert, the reaper's role path and boundary, the six SCP statements, the regions and instance types, a private versioned 90-day trail bucket, and 1-hour admin sessions. Changing the forecast flag, the anomaly frequency, the Savings Plans deny and the trail expiry each made one test fail, then I put them back. `Infrastructure: validate` runs them on every PR.
- **Not proven yet:** a reaper delete, the 6-hour age check and `make nuke`. Lab 00 stays 🔨 until a reaper deletes a test resource.

## Problem
Nobody knows what the AWS account costs, keys live in laptops, and nothing can be torn down with confidence. Before any lab touches AWS, the account needs a safety net: budgets, no static keys, remote state and a one-command teardown.

## What I built
- Three monthly AWS Budgets: `runway-budget-5`, `-15` and `-30`. Each emails at 100% of actual spend. The $30 one also emails at 100% of forecast (YAA-9). A Cost Anomaly Detection monitor watches the whole account and sends a daily email for anomalies of $1 or more. ✅ Budgets and monitor are applied. Code: [infra/](infra/). The alert address comes from the Actions secret `ALERT_EMAIL`.
- ✅ Human sign-in through IAM Identity Center: the user `yaaf`, a passkey, the `runway-admin` permission set with 1-hour sessions, in both accounts (STAT-33). `aws sso login --profile stator` in the terminal. No IAM users and no long-lived keys: the IAM user `yaaf-admin` (YAA-10) was deleted on 2026-11-20.
- OpenTofu pipeline (YAA-11; YAA-12 was merged into it): `make bootstrap` creates the state bucket `runway-tfstate-<account>`, the GitHub OIDC provider, `runway-plan` (PRs, read-only) and `runway-apply` (environment `aws-apply`, `main` only). PRs get `tofu plan` as a comment; merges apply after approval. CI fails any AWS provider without `default_tags` `project`, `lab`, `runway:ephemeral`. Code: [platform/infra](../../platform/infra/README.md). ✅ Ran end to end: see Proof.
- Nightly reaper, dry run only (nightly reaper and `make nuke`, STAT-13): the role `runway-reaper` can read tags and delete nothing. `.github/workflows/reaper.yml` lists resources tagged `runway:ephemeral=true` at 03:17 UTC and writes the list to the job summary, with account numbers hidden. Code: [infra/reaper.tf](infra/reaper.tf).
- ✅ AWS organization with a separate `runway-labs` account (STAT-33): a guardrail SCP on the labs OU (2 regions, no commitments, an instance-type allow-list, no leaving the organization, no IAM role manager), a 90-day organization trail, IAM Access Analyzer, a root sign-in email and IAM Identity Center. Applied from Yaaf's terminal only. Code: [platform/infra/foundation](../../platform/infra/foundation/).
- Not built yet: reaper deletes (each ephemeral lab adds its own, with an age check) and `make nuke`, which waits for the first ephemeral stack (Lab 03).
- ✅ README with proof and cost receipt (YAA-14)

## Cost receipt
| Spent | Idle | Teardown |
|---|---|---|
| $0, no usage billed yet (as of 2026-11-19) | Cents a month for the organization trail's S3 storage. Everything else is $0: budgets without actions and Anomaly Detection are free. The reaper role and the nightly run are free too (IAM roles cost nothing, and Actions minutes are free in a public repo) | `tofu destroy` of this stack; it is not ephemeral |

## Decisions
**Why not Terraform?** OpenTofu, picked on Nov 13. It is open source (MPL 2.0) under the Linux Foundation; Terraform moved to the BSL. It has the S3 lockfile, which removes the DynamoDB lock table. The CLI and the AWS provider are the same, so the skills carry over.

**Why not a narrower apply role?** Labs will create Lambda, EKS, VPCs, Bedrock access and more; a hand-written allowlist would break on every new lab. So the apply role is PowerUserAccess, plus IAM writes only under `/runway/`, and only for roles that carry the `runway-boundary` permissions boundary. Explicit denies stop it from touching its own role and policy, the plan role, the boundary, the OIDC provider and the state bucket settings. Narrowing per lab is a later step, once the labs show what they need.

**Why an approval gate?** The `main` ruleset requires a PR and a green `Docs: lint`, but 0 approvals: Yaaf works alone, and agents open the PRs. So a merge alone must not change AWS. The `aws-apply` environment needs Yaaf's approval and only accepts `main`, and the apply role trusts only that environment. That approval is the one hard gate before real changes.

**Why trust the ID-based subject?** GitHub issues the OIDC `sub` claim in the form `repo:<owner>@<owner id>/<repo>@<repo id>:<context>`, and the roles trust exactly that. IDs never change when a repo is renamed, and a repo re-created under the same name gets a new ID, so nobody else can take over the name and assume the role. `bootstrap.sh` reads the prefix from `gh api repos/<repo>/actions/oidc/customization/sub` instead of rebuilding it from the repo name.

**Why IAM Identity Center now, not the IAM user?** With one account, an IAM user with MFA was enough, and Identity Center needs an organization. Stator now has an organization with a separate labs account (`platform/infra/foundation/`). Identity Center gives one sign-in for both accounts, with a passkey and 1-hour sessions, and no long-lived IAM user left to leak. `yaaf-admin` was deleted on 2026-11-20, once that sign-in worked.

**Why $5 / $15 / $30, and forecast only on $30?** Each step is a louder signal: $5 is the first sign a lab leaked, $15 means act today, $30 is the ceiling. An actual-spend alert fires after the money is spent. A forecast alert on the small budgets would fire on day 1 of a month, when AWS has little data. On the $30 budget it warns before the ceiling is hit.

**Why our own account monitor, not the default AWS services one?** AWS allows one "AWS services" monitor per account and creates it itself (`Default-Services-Monitor`), so a second one is refused. Adopting it would need its random ARN passed into the stack through a secret and a workflow change, and the stack would depend on a resource AWS owns. A custom monitor on the account needs neither. It reports anomalies for the whole account, with the services that caused each one listed in the alert. It does not score each service on its own.

**Why does the reaper trust `main` and not the `aws-apply` environment?** The reaper runs at night with nobody awake, and an environment with a required reviewer would wait for Yaaf. The role only reads tags, so trusting `ref:refs/heads/main` is enough: only code already merged to `main` can run as it. Delete rights will need their own decision.

**Why can't the reaper check a resource's age yet?** The tagging API returns ARNs and tags but no creation time ([AWS docs](https://docs.aws.amazon.com/resourcegroupstagging/latest/APIReference/API_GetResources.html)), and IAM can't express "older than 6 hours". Age has to come from each service's own lookup, so it arrives with that service's delete permission. Until then the report lists candidates and nothing else.

**Why not an immediate anomaly alert?** AWS allows the IMMEDIATE frequency only for SNS subscribers. Email gets DAILY or WEEKLY. DAILY is the fastest email option. An SNS topic needs a topic policy for `costalerts.amazonaws.com` and a confirmed subscription: more moving parts than the alert is worth at this size. The $5 budget covers fast spikes.

## What broke
- The first sign-in was as **root**. Fixed in YAA-10.
- `sso-admin create-instance` is refused for an organization's management account.
- After deleting the organization, an account instance of Identity Center rejected `create-permission-set`: account instances can't grant access to AWS accounts. Dropped Identity Center.
- The first apply created the 3 budgets, then failed on the anomaly monitor ([run log](https://github.com/yaaf-some/cloud-project/actions/runs/44581039403/attempts/1)). A rerun of the same run failed the same way: `Limit exceeded on dimensional spend monitor creation`. The account already had AWS's default services monitor (`aws ce get-anomaly-monitors` showed it). Fix: our own account-level monitor.
- The first `tofu plan` in CI failed with "Not authorized to perform sts:AssumeRoleWithWebIdentity". The roles trusted `repo:yaaf-some/cloud-project:pull_request`, but this repo has immutable OIDC subjects, so the token's `sub` carries the owner and repo IDs. The trust policy had matched the code and the code was wrong; nothing in AWS showed the real value. Fix: trust the subject prefix GitHub reports, and print the token's claims (`tools/oidc-claims.py`) whenever sign-in fails.
- `tofu plan` found no credentials: the AWS provider (`~> 5.80`) didn't read the CLI login. Fix: `eval "$(aws configure export-credentials --format env)"`. `make bootstrap` does this for you (YAA-11).
- The anomaly monitor spec lacked `ProductAttributes`, which AWS now returns, so every plan wanted to replace the monitor. Found in the plan of the rename PR. Fix: add the key.
- Three stray budgets from an earlier manual attempt (`runway-monthly-5usd`, `-15usd`, `-30usd`) doubled the budget list. Yaaf deleted them by hand on Nov 19. The pipeline's `runway-budget-*` stayed.
- The `aws-apply` run for PR #8 stayed in "waiting" for five days. Yaaf had to reject it by hand on Nov 19 (it shows as cancelled).
- The IAM admin user could not open Cost Explorer or billing pages at first. It needed a one-time root step to allow IAM user access to billing and Cost Explorer ([AWS docs](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/control-access-billing.html)). Yaaf got it working on Nov 19.
- The first `tofu test` runs failed three ways. The mocked provider invents random strings for computed values, and the AWS provider rejects them as ARNs: fixing `account_id`, `partition`, the policy JSON and the monitor ARN in the test fixed it. A list compared with `==` to a literal list is never equal (list vs tuple), so the test used `toset`. And `tofu test` 1.13.9 crashes on a stack with an `import` block, so the foundation stack lost its block after the first apply.

## What I'd change
- Grant billing and Cost Explorer access, and delete stale manual resources, before the first apply.
- Run `aws ce get-anomaly-monitors` before writing the monitor. It lists the account's default monitor, which is why a second services monitor is refused.
- Cancel or reject a waiting `aws-apply` run when its PR is superseded, so it does not sit for days.

**Target roles:** SA, Platform, Cloud, SRE, Security
