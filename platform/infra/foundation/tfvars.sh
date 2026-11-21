#!/usr/bin/env bash
# Writes foundation.auto.tfvars from what AWS holds now, so nothing is typed by hand.
# Run with `make tfvars` after `aws sso login --profile stator`.
# Prints no value. Writes only that git-ignored file, readable by you alone.
# Needs an existing organization, labs account, root sign-in alert and Identity Center user:
# for the very first apply there is nothing to read yet, so write the file by hand (../README.md).
set -euo pipefail

out=foundation.auto.tfvars
labs_name=${LABS_ACCOUNT_NAME:-runway-labs}
topic=runway-root-sign-in

fail() { echo "tfvars: $*" >&2; exit 1; }

if [ -e "$out" ] && [ "${FORCE:-}" != 1 ]; then
  fail "$out exists. Run FORCE=1 make tfvars to overwrite it."
fi

# get <what> <command...>: runs the command, fails on an empty or odd value, prints the value.
get() {
  local what=$1 v
  shift
  v=$("$@") || fail "the lookup for $what failed"
  case $v in
    '' | None | null) fail "$what is empty" ;;
    *$'\n'* | *$'\t'* | *'"'* | *'\'*) fail "$what has more than one value or a character this file cannot hold" ;;
  esac
  printf '%s' "$v"
}

# count <what> <command...>: fails unless the command prints exactly 1.
count() {
  local what=$1 n
  shift
  n=$("$@") || fail "the lookup for $what failed"
  [ "$n" = 1 ] || fail "expected exactly 1 $what, found $n"
}

account=$(get "the account ID" aws sts get-caller-identity --query Account --output text)

count "organization" aws organizations list-roots --query 'length(Roots)' --output text
org_id=$(get "the organization ID" aws organizations describe-organization --query Organization.Id --output text)
labs_email=$(get "the email of $labs_name" aws organizations list-accounts \
  --query "Accounts[?Name=='$labs_name'].Email | [0]" --output text)

topic_arn="arn:aws:sns:us-east-1:$account:$topic"
count "subscription on $topic" aws sns list-subscriptions-by-topic --region us-east-1 \
  --topic-arn "$topic_arn" --query 'length(Subscriptions)' --output text
alert_email=$(get "the alert email" aws sns list-subscriptions-by-topic --region us-east-1 \
  --topic-arn "$topic_arn" --query 'Subscriptions[0].Endpoint' --output text)

count "Identity Center instance" aws sso-admin list-instances --region us-east-1 \
  --query 'length(Instances)' --output text
store=$(get "the identity store ID" aws sso-admin list-instances --region us-east-1 \
  --query 'Instances[0].IdentityStoreId' --output text)
count "Identity Center user" aws identitystore list-users --region us-east-1 \
  --identity-store-id "$store" --query 'length(Users)' --output text
user() { get "the user's $1" aws identitystore list-users --region us-east-1 \
  --identity-store-id "$store" --query "Users[0].$1" --output text; }
user_name=$(user UserName)
given_name=$(user Name.GivenName)
family_name=$(user Name.FamilyName)
user_email=$(user 'Emails[0].Value')

umask 077
tmp=$(mktemp "$out.XXXXXX")
trap 'rm -f "$tmp"' EXIT
{
  printf 'organization_id    = "%s"\n' "$org_id"
  printf 'labs_account_email = "%s"\n' "$labs_email"
  printf 'alert_email        = "%s"\n' "$alert_email"
  printf 'sso_user = {\n'
  printf '  user_name   = "%s"\n' "$user_name"
  printf '  given_name  = "%s"\n' "$given_name"
  printf '  family_name = "%s"\n' "$family_name"
  printf '  email       = "%s"\n' "$user_email"
  printf '}\n'
} >"$tmp"
mv "$tmp" "$out"
trap - EXIT
echo "tfvars: wrote $out (5 values read from AWS, none printed). Next: make plan."
