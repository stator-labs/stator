#!/usr/bin/env bash
# Derives one CI role ARN and the state bucket from an account ID (IaC platform v2), so a
# consumer repo sets two variables instead of one per role.
#   ci-target.sh <account> <preset>     account: a stacks.json account (labs); preset: plan-pr,
#                                       plan-main, apply or reaper
# Reads VARS_JSON (`toJSON(vars)`): AWS_<ACCOUNT>_ACCOUNT_ID and AWS_REGION. Fails fast when
# either is missing, so a misordered cutover stops here instead of at an AWS error.
# Writes account_id, role_arn, bucket and region to $GITHUB_OUTPUT and masks the account ID.
set -euo pipefail
account=${1:?usage: ci-target.sh <account> <preset>}
preset=${2:?usage: ci-target.sh <account> <preset>}
: "${VARS_JSON:?set VARS_JSON to toJSON(vars)}" "${GITHUB_OUTPUT:?}"

case "$preset" in
  plan-pr | plan-main | apply | reaper) ;;
  *) echo "::error::unknown preset '$preset'" >&2; exit 2 ;;
esac
if ! [[ "$account" =~ ^[a-z][a-z0-9]*$ ]]; then
  echo "::error::account must be lowercase letters and digits, got '$account'" >&2
  exit 2
fi

name="AWS_$(tr '[:lower:]' '[:upper:]' <<<"$account")_ACCOUNT_ID"
id=$(jq -r --arg n "$name" '.[$n] // empty' <<<"$VARS_JSON")
region=$(jq -r '.AWS_REGION // empty' <<<"$VARS_JSON")
if ! [[ "$id" =~ ^[0-9]{12}$ ]]; then
  echo "::error::Actions variable $name is not a 12-digit account ID. Run 'make cutover' in platform/infra/labs-bootstrap." >&2
  exit 1
fi
if [ -z "$region" ]; then
  echo "::error::Actions variable AWS_REGION is not set" >&2
  exit 1
fi

echo "::add-mask::$id"
{
  echo "account_id=$id"
  echo "role_arn=arn:aws:iam::$id:role/stator/platform/stator-ci-$preset"
  echo "bucket=stator-tfstate-$id"
  echo "region=$region"
} >>"$GITHUB_OUTPUT"
echo "ci-target: $account/$preset -> stator-ci-$preset, bucket stator-tfstate-<account>"
