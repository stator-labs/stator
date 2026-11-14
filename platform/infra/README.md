# platform/infra

OpenTofu stacks. GitHub Actions plans them on every PR and applies them after merge ([tofu.yml](../../.github/workflows/tofu.yml)). Nobody runs `tofu apply` by hand, except `make bootstrap`.

## Layout
- **One folder per stack:** `platform/infra/<stack>/` or `labs/<lab>/infra/`. A stack is a folder with `.tf` files.
- **`bootstrap/`** creates the state bucket, the GitHub OIDC provider and the `runway-plan` / `runway-apply` roles. Only Yaaf applies it, once, with `make bootstrap ALERT_EMAIL=...`. CI lints it but never plans or applies it.
- **`modules/`** holds shared modules. A change there plans every stack.

## Rules every stack follows
- **State:** S3 backend, key `<stack>/terraform.tfstate`. For a lab the stack name is the lab folder, e.g. `03-ephemeral-eks/terraform.tfstate`. The bucket is passed by CI (`-backend-config=bucket=$TF_STATE_BUCKET`), so no account ID is in code. Locking is the S3 lockfile (`use_lockfile = true`), not DynamoDB. `tools/tofu-stacks.py check` fails the PR if the key is wrong or reused.
- **Tags:** every `provider "aws"` block has `default_tags` with `project`, `lab` and `runway:ephemeral` (`"true"` or `"false"`). The checkov check `CKV_RUNWAY_1` ([tools/checkov](../../tools/checkov/)) fails the PR otherwise.
- **IAM:** roles and policies go under path `/runway/`, and every role sets `permissions_boundary` to the `runway-boundary` policy. The apply role cannot create one without it.
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
