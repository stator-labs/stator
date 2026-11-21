# platform/infra

OpenTofu stacks. GitHub Actions plans them on every PR and applies them after merge ([infrastructure.yml](../../.github/workflows/infrastructure.yml)). Nobody runs `tofu apply` by hand, except the two terminal-only stacks below.

## Layout
- **One folder per stack:** `platform/infra/<stack>/` or `labs/<lab>/infra/`. A stack is a folder with `.tf` files.
- **`bootstrap/`** creates the state bucket, the GitHub OIDC provider and the `runway-plan` / `runway-apply` roles. Only Yaaf applies it, once, with `make bootstrap ALERT_EMAIL=<your alert email>`. CI lints it but never plans or applies it. The roles trust the OIDC subject prefix GitHub reports for the repo (`bootstrap.sh` reads it), not a name typed into the code. If a job cannot sign in, its log prints the token's claims (`tools/oidc-claims.py`): compare `sub` and `aud` with the role's trust policy.
- **`foundation/`** manages the AWS organization from the management account: the `runway-labs` account in the `stator-labs` OU, the guardrail SCP, centralized root access, the organization trail (90 days), IAM Access Analyzer, a root sign-in alert and IAM Identity Center. Only Yaaf applies it, with `make plan` and `make apply` in that folder. Personal values (emails, names, organization ID) go in `foundation.auto.tfvars`, which git ignores. CI lints it but never plans or applies it (`TERMINAL_ONLY` in `tools/tofu-stacks.py`). It also holds the budgets, the cost anomaly monitor and the labs kill switch: a $30-a-month budget on the labs account whose action attaches a deny-new-spend SCP to the labs OU (`kill-switch.tf`).
- **`modules/`** holds shared modules. A change there plans every stack.

## Rules every stack follows
- **State:** S3 backend, key `<stack>/terraform.tfstate`. For a lab the stack name is the lab folder, e.g. `03-ephemeral-eks/terraform.tfstate`. The bucket is passed by CI (`-backend-config=bucket=$TF_STATE_BUCKET`), so no account ID is in code. Locking is the S3 lockfile (`use_lockfile = true`), not DynamoDB. `tools/tofu-stacks.py check` fails the PR if the key is wrong or reused.
- **Tags:** every `provider "aws"` block has `default_tags` with `project`, `lab` and `runway:ephemeral` (`"true"` or `"false"`). The checkov check `CKV_RUNWAY_1` ([tools/checkov](../../tools/checkov/)) fails the PR otherwise.
- **IAM:** roles and policies go under path `/runway/`, and every role sets `permissions_boundary` to the `runway-boundary` policy. The apply role cannot create one without it.
- **Alert email:** a stack that needs it declares `variable "alert_email"` with `sensitive = true` and no default. CI passes it as `TF_VAR_alert_email` from the Actions secret `ALERT_EMAIL` (set by `make bootstrap`). A stack without that variable ignores it. Never put the address in code, a variable or a PR: the repo is public.
- **Roles GitHub Actions can assume:** a stack that creates one declares `variable "github_sub_prefix"` (no default). CI passes it from the repo variable `OIDC_SUB_PREFIX`, which `make bootstrap` sets from GitHub's own OIDC settings. Trust `"${var.github_sub_prefix}:<context>"` (`pull_request`, `environment:<name>` or `ref:refs/heads/main`), never a name typed into code.
- **Lock file:** commit `.terraform.lock.hcl`. CI inits with `-lockfile=readonly`.

## Add a stack
1. Create the folder with this `versions.tf` (change `key` and `lab`):

   ```hcl
   terraform {
     required_version = "~> 1.13"
     required_providers {
       aws = { source = "hashicorp/aws", version = "~> 6.73" }
     }
     backend "s3" {
       key          = "03-ephemeral-eks/terraform.tfstate"
       region       = "us-west-2"
       encrypt      = true
       use_lockfile = true
     }
   }

   provider "aws" {
     region = "us-west-2"
     default_tags {
       tags = { project = "runway", lab = "03", "runway:ephemeral" = "true" }
     }
   }
   ```
2. `tofu init -backend=false && tofu providers lock -platform=linux_amd64 -platform=darwin_arm64`, then commit the lock file.
3. Open a PR. The plan shows up as one PR comment, updated on every push.
4. Merge. Approve the `aws-apply` deployment in the Actions tab. The apply runs with `runway-apply`.

To delete a stack, merge a PR that empties it first (destroys its resources), then a PR that removes the folder. CI skips folders that no longer exist.

## Apply the foundation (Yaaf, once)
1. Console, IAM Identity Center: enable the organization instance in `us-east-1`. It has no API, and it can't move region later.
2. `aws organizations list-aws-service-access-for-organization`: every service listed must be in `service_access_principals`. Add any extra to the tfvars.
3. IAM role manager off in management: `aws cloudtrail lookup-events --region us-east-1 --lookup-attributes AttributeKey=EventName,AttributeValue=AcquireRole` should return nothing. Then `aws iam put-account-properties --properties RoleManager/Enabled=false`.
4. Write `foundation.auto.tfvars`: `organization_id`, `labs_account_email`, `alert_email`, `sso_user`. Git ignores it (the repo is public), so a new checkout needs it again. When the organization, labs account, root sign-in alert and Identity Center user already exist, `make tfvars` rebuilds it from AWS (after `aws sso login --profile stator`); `FORCE=1 make tfvars` overwrites. For the very first apply nothing exists yet: write it by hand. Never type values you can read from AWS: a wrong email makes the plan replace the labs account.
5. Add an `import` block for the organization to `organization.tf`: `to = aws_organizations_organization.this`, `id = var.organization_id`. `make plan`. Expect 1 import, the organization changed in place with additions only, and no destroy. Anything else: stop.
6. `make apply`. Then delete the `import` block: `tofu test` cannot run a stack that has one. Confirm the SNS email. In Identity Center, send your user the password email, register a passkey, and sign in to both accounts. Then delete `yaaf-admin`.

## Arm the budget kill switch (Yaaf, once)
The budgets and the anomaly monitor moved from the Lab 00 stack to `foundation/`, and the kill switch is new. Order matters: a second create would duplicate the anomaly monitor.
1. Merge the PR. CI plans `labs/00-account-foundation/infra`. Expect `removed` for 3 budgets, the monitor and the subscription, and **0 to destroy**. Approve `aws-apply`: it makes the stack forget them. Nothing is deleted in AWS.
2. `aws sso login --profile stator`, then in `platform/infra/foundation`: `make import-budgets`. It imports the 5 resources and skips any already imported.
3. `make plan`. Expect 5 to add (the SCP, the kill-switch budget, its role, the role policy and the action). The imported budgets, monitor and subscription may show in-place changes that only add the tag `runway:stack = foundation`. Any other change, or any destroy: stop.
4. `make apply`.
5. Check it is armed and not firing: `aws budgets describe-budget-actions-for-budget --account-id "$(aws sts get-caller-identity --query Account --output text)" --budget-name runway-labs-kill-switch --query 'Actions[].Status'` should say `STANDBY`. The SCP must be attached to nothing yet: `aws organizations list-targets-for-policy --policy-id <id of runway-labs-deny-new-spend>` returns no targets.
6. Game day (STAT-36, step D): attach and detach the SCP by hand, and record the result in the Lab 00 README.
Remove `labs/00-account-foundation/infra/moved-to-foundation.tf` in a later PR, once step 2 is done.

## Decisions
**Why is the foundation stack terminal-only?** It changes the organization itself: accounts, SCPs and who can sign in. Giving the CI apply role those rights would let one approved PR rewrite the guardrails that limit that same role. A plan from Yaaf's terminal, read before typing `yes`, is the gate.

**Why import the organization instead of creating it?** It was created in the console with centralized root access already on. The import brings it under code without recreating anything. The block is removed after the first apply (done 2026-11-20). The one risk is `service_access_principals`: a service missing from that list loses trusted access on apply, so the first plan must show additions only.

**Why do the budgets and the kill switch live in the foundation stack?** They belong to the management account, because only it can attach an SCP and only it sees the spend of every account. When the CI roles move to the labs account (STAT-36), they will not be able to manage management-account budgets, and CI should not hold the right to attach an SCP. So these resources join the stacks only Yaaf applies.
