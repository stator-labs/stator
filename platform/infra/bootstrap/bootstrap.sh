#!/usr/bin/env bash
# Called by `make bootstrap`. Idempotent:
#   1. apply this stack (local state on the first run, the S3 bucket afterwards)
#   2. move local state into the bucket (first run only)
#   3. create/update GitHub environment `aws-apply` and the repo variables
set -euo pipefail
cd "$(dirname "$0")"

MODE=${1:-apply}
: "${AWS_PROFILE:?}" "${REPO:?}"
STATE_KEY=bootstrap/terraform.tfstate
OVERRIDE=local_override.tf

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

ALERT_EMAIL=$(printf '%s' "${ALERT_EMAIL:-}" | tr -d '[:space:]')
[ "$MODE" = plan ] || [ -n "$ALERT_EMAIL" ] \
  || die "ALERT_EMAIL is empty. Set it in the environment or run: make bootstrap ALERT_EMAIL=<your alert email>"
for bin in aws tofu gh; do command -v "$bin" >/dev/null || die "$bin not found"; done
gh auth status >/dev/null 2>&1 || die "gh is not logged in: run gh auth login"

say "AWS credentials from profile $AWS_PROFILE"
# The AWS provider does not read the `aws login` cache; export short-lived keys
# into this process only (see Lab 00 "What broke"). Never printed.
creds=$(aws configure export-credentials --profile "$AWS_PROFILE" --format env) \
  || die "no credentials: run aws login --profile $AWS_PROFILE"
eval "$creds"
unset creds AWS_PROFILE
export AWS_REGION=us-west-2 AWS_DEFAULT_REGION=us-west-2   # same as versions.tf
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
CALLER=$(aws sts get-caller-identity --query Arn --output text)
echo "caller: $CALLER"
case "$CALLER" in *:root) die "signed in as root; use the yaaf-admin user" ;; esac

BUCKET=runway-tfstate-$ACCOUNT

# Remote state exists -> normal run. A 404 (no bucket or no object) -> first run.
# Any other error stops here, so a rerun never starts over with empty local state.
if probe=$(aws s3api head-object --bucket "$BUCKET" --key "$STATE_KEY" 2>&1); then
  say "State found in s3://$BUCKET/$STATE_KEY"
  rm -f "$OVERRIDE"
  tofu init -input=false -reconfigure -backend-config="bucket=$BUCKET"
  FIRST_RUN=false
elif printf '%s' "$probe" | grep -qE '\(404\)|Not Found'; then
  [ "$MODE" = plan ] && die "no remote state yet; run make bootstrap first"
  say "First run: local state (terraform.tfstate in this folder)"
  printf 'terraform {\n  backend "local" {}\n}\n' >"$OVERRIDE"
  tofu init -input=false -reconfigure
  FIRST_RUN=true
else
  die "cannot check s3://$BUCKET/$STATE_KEY: $probe"
fi

if [ "$MODE" = plan ]; then
  tofu plan -input=false
  exit 0
fi

say "tofu apply"
tofu apply   # shows the plan and asks for "yes"

if [ "$FIRST_RUN" = true ]; then
  say "Moving state into s3://$BUCKET/$STATE_KEY"
  rm -f "$OVERRIDE"
  tofu init -input=false -migrate-state -force-copy -backend-config="bucket=$BUCKET"
  aws s3api head-object --bucket "$BUCKET" --key "$STATE_KEY" >/dev/null \
    || die "state not found in the bucket after migration; keep terraform.tfstate and rerun"
  rm -f terraform.tfstate terraform.tfstate.backup
fi

PLAN_ROLE=$(tofu output -raw plan_role_arn)
APPLY_ROLE=$(tofu output -raw apply_role_arn)
REGION=$(tofu output -raw region)

say "GitHub environment aws-apply on $REPO"
USER_ID=$(gh api user --jq .id)
gh api -X PUT "repos/$REPO/environments/aws-apply" --input - >/dev/null <<JSON
{
  "reviewers": [{"type": "User", "id": $USER_ID}],
  "prevent_self_review": false,
  "deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}
}
JSON
if ! gh api "repos/$REPO/environments/aws-apply/deployment-branch-policies" \
     --jq '.branch_policies[] | select(.type == "branch") | .name' | grep -qx main; then
  gh api -X POST "repos/$REPO/environments/aws-apply/deployment-branch-policies" \
    -f name=main -f type=branch >/dev/null
fi

say "Repo variables"
set_var() { gh variable set "$1" --repo "$REPO" --body "$2"; }
set_var AWS_PLAN_ROLE_ARN "$PLAN_ROLE"
set_var AWS_APPLY_ROLE_ARN "$APPLY_ROLE"
set_var TF_STATE_BUCKET "$BUCKET"
set_var AWS_REGION "$REGION"
set_var ALERT_EMAIL "$ALERT_EMAIL"

say "Done"
gh variable list --repo "$REPO"
gh api "repos/$REPO/environments/aws-apply" \
  --jq '"aws-apply reviewers: \([.protection_rules[]? | select(.type=="required_reviewers") | .reviewers[].reviewer.login] | join(","))"'
