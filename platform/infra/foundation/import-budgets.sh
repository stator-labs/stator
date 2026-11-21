#!/usr/bin/env bash
# One time, after the Lab 00 stack has forgotten them (moved-to-foundation.tf applied by CI):
# imports the three budgets and the anomaly monitor and subscription into this stack's state.
# Run with `make import-budgets`. Safe to rerun: what is already in state is skipped.
# Reads names from AWS and prints no account number or email address.
# Never run `make apply` before this has succeeded: it would try to create them a second time.
set -euo pipefail

fail() { echo "import-budgets: $*" >&2; exit 1; }

state=$(tofu state list 2>/dev/null) || fail "cannot read the state. Run make init first."
account=$(aws sts get-caller-identity --query Account --output text) || fail "cannot read the account ID. Run aws sso login."
case $account in '' | None) fail "the account ID is empty" ;; esac

# imp <address> <id>: imports one resource unless it is already in state.
imp() {
  if grep -qxF -- "$1" <<<"$state"; then
    echo "skip: $1 is already in state"
    return
  fi
  tofu import -input=false "$1" "$2" >/dev/null || fail "the import of $1 failed"
  echo "imported: $1"
}

# find <what> <query>: one Cost Explorer lookup that must return one value.
find_ce() {
  local v
  v=$(aws ce "$2" --region us-east-1 --query "$3" --output text) || fail "the lookup for $1 failed"
  case $v in '' | None | null) fail "$1 was not found" ;; esac
  printf '%s' "$v"
}

# Look everything up first, so a missing resource stops the script before it imports anything.
monitor=$(find_ce "the anomaly monitor runway-account" get-anomaly-monitors "AnomalyMonitors[?MonitorName=='runway-account'].MonitorArn | [0]")
subscription=$(find_ce "the anomaly subscription runway-anomaly-email" get-anomaly-subscriptions "AnomalySubscriptions[?SubscriptionName=='runway-anomaly-email'].SubscriptionArn | [0]")

for n in 5 15 30; do
  imp "aws_budgets_budget.monthly[\"$n\"]" "$account:runway-budget-$n"
done
imp aws_ce_anomaly_monitor.account "$monitor"
imp aws_ce_anomaly_subscription.email "$subscription"

echo "import-budgets: done. Next: make plan. Expect the kill switch to be added and nothing else."
