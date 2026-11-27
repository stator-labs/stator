#!/usr/bin/env bash
# Two rolling GitHub issues for infrastructure on main (IaC platform v2). One of each at most,
# so there is never a run ID to hunt for.
#   apply-alert.sh waiting <environment>   "Infrastructure: apply waiting": rewrite the body to
#                                          link this run and its plans (SUMMARY, markdown)
#   apply-alert.sh superseded              same issue, if open: say a newer push is planning
#   apply-alert.sh idle                    close it: nothing waits
#   apply-alert.sh failing <what failed>   "Infrastructure: main is failing": open, or comment
#   apply-alert.sh healthy                 close it after a clean run
# Needs GH_TOKEN (issues: write), GITHUB_REPOSITORY, GITHUB_SHA, GITHUB_SERVER_URL, GITHUB_RUN_ID.
# ASSIGNEE (optional) is assigned on create, so the issue notifies someone.
set -euo pipefail
: "${GH_TOKEN:?}" "${GITHUB_REPOSITORY:?}" "${GITHUB_SHA:?}" "${GITHUB_SERVER_URL:?}" "${GITHUB_RUN_ID:?}"

WAITING="Infrastructure: apply waiting"
FAILING="Infrastructure: main is failing"
repo=(--repo "$GITHUB_REPOSITORY")
run_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
sha=${GITHUB_SHA:0:12}

find_open() {
  gh issue list "${repo[@]}" --state open --search "\"$1\" in:title" --json number,title \
    --jq "[.[] | select(.title == \"$1\")][0].number // empty"
}

upsert() { # title body
  local n
  n=$(find_open "$1")
  if [ -n "$n" ]; then
    gh issue edit "$n" "${repo[@]}" --body "$2" >/dev/null
  else
    gh issue create "${repo[@]}" --title "$1" --body "$2" ${ASSIGNEE:+--assignee "$ASSIGNEE"} >/dev/null
  fi
}

close_if_open() { # title comment
  local n
  n=$(find_open "$1")
  [ -z "$n" ] || gh issue close "$n" "${repo[@]}" --comment "$2" >/dev/null
}

case "${1:-}" in
  waiting)
    env=${2:?say which environment}
    plans=""
    [ -z "${SUMMARY:-}" ] || plans=$(printf '\n\n## Plans\n\n%s' "$SUMMARY")
    upsert "$WAITING" "**Waiting for you:** [run on \`$sha\`]($run_url)

1. Open the run link.
2. Read the plans below (or the run summary).
3. Click **Review deployments**, tick **$env**, then **Approve and deploy**.

Only this run can apply. Older waiting runs are cancelled by the Supersede workflow, and an older run that is approved anyway exits as \"superseded\". This body is rewritten for every new plan.$plans"
    ;;
  superseded)
    n=$(find_open "$WAITING")
    [ -z "$n" ] || gh issue edit "$n" "${repo[@]}" --body "A newer push (\`$sha\`) is planning: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/workflows/infrastructure.yml?query=branch%3Amain

The older waiting run was cancelled. This issue updates when the new plan is ready, or closes if it has no changes." >/dev/null
    ;;
  idle)
    close_if_open "$WAITING" "Nothing waits after \`$sha\`: $run_url"
    ;;
  failing)
    what=${2:?say what failed}
    body="$what failed on \`$sha\`: $run_url

Main stays out of sync with AWS until a run passes. Every push to main plans every stack, so the next merge retries. To retry without a merge, open the run and click **Re-run all jobs**."
    n=$(find_open "$FAILING")
    if [ -n "$n" ]; then
      gh issue comment "$n" "${repo[@]}" --body "$body" >/dev/null
    else
      gh issue create "${repo[@]}" --title "$FAILING" --body "$body" ${ASSIGNEE:+--assignee "$ASSIGNEE"} >/dev/null
    fi
    ;;
  healthy)
    close_if_open "$FAILING" "Passed on \`$sha\`: $run_url"
    ;;
  *)
    echo "usage: apply-alert.sh waiting <environment> | superseded | idle | failing <what> | healthy" >&2
    exit 2
    ;;
esac
