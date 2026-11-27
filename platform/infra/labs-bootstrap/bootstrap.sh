#!/usr/bin/env bash
# Terminal-only bootstrap for the labs account (STAT-36 Step B). Idempotent:
#   apply   - create stator-* state bucket, OIDC provider, and plan/apply/reaper roles in labs
#             (does NOT flip GitHub repo variables until you run `make cutover`)
#   plan    - read-only drift check against remote state
#   cutover - point GitHub repo variables at the labs roles and state bucket
set -euo pipefail
cd "$(dirname "$0")"

MODE=${1:-apply}
: "${AWS_PROFILE:?}" "${REPO:?}"
STATE_KEY=labs-bootstrap/terraform.tfstate
OVERRIDE=local_override.tf

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

for bin in aws tofu gh; do command -v "$bin" >/dev/null || die "$bin not found"; done
gh auth status >/dev/null 2>&1 || die "gh is not logged in: run gh auth login"

say "GitHub OIDC subject of $REPO"
SUB_PREFIX=$(gh api "repos/$REPO/actions/oidc/customization/sub" --jq '.sub_claim_prefix // empty') \
  || die "cannot read OIDC settings of $REPO (gh login needs admin rights)"
[ -n "$SUB_PREFIX" ] \
  || die "GitHub reports no sub_claim_prefix for $REPO"
echo "sub prefix: $SUB_PREFIX"
export TF_VAR_github_sub_prefix="$SUB_PREFIX"

say "AWS credentials from profile $AWS_PROFILE"
creds=$(aws configure export-credentials --profile "$AWS_PROFILE" --format env) \
  || die "no credentials: run aws sso login --profile $AWS_PROFILE"
eval "$creds"
unset creds AWS_PROFILE
export AWS_REGION=us-west-2 AWS_DEFAULT_REGION=us-west-2
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
CALLER=$(aws sts get-caller-identity --query Arn --output text)
echo "caller: $CALLER"
case "$CALLER" in *:root) die "signed in as root; use your Identity Center labs profile" ;; esac

# Refuse to run against the organization management account.
MASTER=$(aws organizations describe-organization --query Organization.MasterAccountId --output text 2>/dev/null || true)
if [ -n "$MASTER" ] && [ "$ACCOUNT" = "$MASTER" ]; then
  die "profile points at the management account; switch to AWS_PROFILE=stator-labs"
fi

BUCKET=stator-tfstate-$ACCOUNT

if probe=$(aws s3api head-object --bucket "$BUCKET" --key "$STATE_KEY" 2>&1); then
  say "State found in s3://$BUCKET/$STATE_KEY"
  rm -f "$OVERRIDE"
  tofu init -input=false -reconfigure -backend-config="bucket=$BUCKET"
  FIRST_RUN=false
elif printf '%s' "$probe" | grep -qE '\(404\)|Not Found'; then
  [ "$MODE" = apply ] || die "no remote state yet; run make bootstrap first"
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

if [ "$MODE" = apply ]; then
  say "tofu apply (labs account)"
  tofu apply

  if [ "$FIRST_RUN" = true ]; then
    say "Moving state into s3://$BUCKET/$STATE_KEY"
    rm -f "$OVERRIDE"
    tofu init -input=false -migrate-state -force-copy -backend-config="bucket=$BUCKET"
    aws s3api head-object --bucket "$BUCKET" --key "$STATE_KEY" >/dev/null \
      || die "state not found after migration; keep terraform.tfstate and rerun"
    rm -f terraform.tfstate terraform.tfstate.backup
  fi

  say "Bootstrapped in labs (repo variables unchanged until 'make cutover')"
  tofu output
  exit 0
fi

if [ "$MODE" = cutover ]; then
  PLAN_ROLE=$(tofu output -raw plan_role_arn)
  PLAN_MAIN_ROLE=$(tofu output -raw plan_main_role_arn)
  APPLY_ROLE=$(tofu output -raw apply_role_arn)
  REAPER_ROLE=$(tofu output -raw reaper_role_arn)
  REGION=$(tofu output -raw region)

  say "Pointing $REPO Actions variables at the labs account"
  set_var() { gh variable set "$1" --repo "$REPO" --body "$2"; }
  set_var AWS_PLAN_ROLE_ARN "$PLAN_ROLE"
  set_var AWS_PLAN_MAIN_ROLE_ARN "$PLAN_MAIN_ROLE"
  set_var AWS_APPLY_ROLE_ARN "$APPLY_ROLE"
  set_var AWS_REAPER_ROLE_ARN "$REAPER_ROLE"
  set_var TF_STATE_BUCKET "$BUCKET"
  set_var AWS_REGION "$REGION"
  set_var OIDC_SUB_PREFIX "$SUB_PREFIX"

  say "Cutover complete"
  gh variable list --repo "$REPO" --json name --jq '.[].name | "variable: " + .'
  exit 0
fi

die "unknown mode '$MODE' (expected apply, plan, or cutover)"
