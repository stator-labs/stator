#!/usr/bin/env bash
# Keeps one GitHub issue open while infrastructure on main is failing (STAT-34).
#   apply-alert.sh open <what failed>   open the issue, or comment on the one already open
#   apply-alert.sh close                close it after a clean apply
# A rejected aws-apply approval never calls this: steps don't run in a rejected job.
# Needs GH_TOKEN (issues: write), GITHUB_REPOSITORY, GITHUB_SHA, GITHUB_SERVER_URL, GITHUB_RUN_ID.
# ASSIGNEE (optional) is assigned so the issue notifies someone; a bot-opened issue otherwise
# reaches only people watching all repo activity.
set -euo pipefail
: "${GH_TOKEN:?}" "${GITHUB_REPOSITORY:?}" "${GITHUB_SHA:?}" "${GITHUB_SERVER_URL:?}" "${GITHUB_RUN_ID:?}"

PREFIX="Infrastructure: main is failing"
run_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
open=$(gh issue list --repo "$GITHUB_REPOSITORY" --state open --search "\"$PREFIX\" in:title" \
  --json number,title --jq "[.[] | select(.title | startswith(\"$PREFIX\"))][0].number // empty")

case "${1:-}" in
  open)
    what=${2:?say what failed}
    body="$what failed on \`${GITHUB_SHA:0:12}\`: $run_url

Main stays out of sync with AWS until a run applies cleanly. The next push to main replans every stack changed since the last green run. To retry without a push, re-run all jobs of the latest run."
    if [ -n "$open" ]; then
      gh issue comment "$open" --repo "$GITHUB_REPOSITORY" --body "$body"
    else
      gh issue create --repo "$GITHUB_REPOSITORY" --title "$PREFIX" --body "$body" ${ASSIGNEE:+--assignee "$ASSIGNEE"}
    fi
    ;;
  close)
    [ -z "$open" ] && exit 0
    gh issue close "$open" --repo "$GITHUB_REPOSITORY" --comment "Applied cleanly on \`${GITHUB_SHA:0:12}\`: $run_url"
    ;;
  *)
    echo "usage: apply-alert.sh open <what failed> | close" >&2
    exit 2
    ;;
esac
