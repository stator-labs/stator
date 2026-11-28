#!/usr/bin/env bash
# Called by `make bootstrap`. Idempotent:
#   1. apply this stack (local state on the first run, the S3 bucket afterwards)
#   2. move local state into the bucket (first run only)
# It writes nothing to GitHub: CI never assumes a management-account role (IaC platform v2).
set -euo pipefail
cd "$(dirname "$0")"

MODE=${1:-apply}
: "${AWS_PROFILE:?}"
STATE_KEY=bootstrap/terraform.tfstate
OVERRIDE=local_override.tf

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

for bin in aws tofu; do command -v "$bin" >/dev/null || die "$bin not found"; done

say "AWS credentials from profile $AWS_PROFILE"
# Export the profile's short-lived keys (Identity Center session)
# into this process only (see Lab 00 "What broke"). Never printed.
creds=$(aws configure export-credentials --profile "$AWS_PROFILE" --format env) \
  || die "no credentials: run aws sso login --profile $AWS_PROFILE"
eval "$creds"
unset creds AWS_PROFILE
export AWS_REGION=us-west-2 AWS_DEFAULT_REGION=us-west-2   # same as versions.tf
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
CALLER=$(aws sts get-caller-identity --query Arn --output text)
echo "caller: $CALLER"
case "$CALLER" in *:root) die "signed in as root; use your Identity Center user" ;; esac

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

say "Done"
echo "state bucket: $(tofu output -raw state_bucket)"
