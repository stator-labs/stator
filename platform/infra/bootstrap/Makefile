# The one manual step in Runway. Run once on Yaaf's Mac; safe to rerun.
#   aws login --profile runway && gh auth login
#   make bootstrap ALERT_EMAIL=<your alert email>
# ALERT_EMAIL can also come from the environment. Never commit it: the repo is public.
# The logic lives in bootstrap.sh: macOS ships make 3.81, which has no .ONESHELL,
# and the exported AWS credentials must survive from one command to the next.

AWS_PROFILE ?= runway
REPO        ?= yaaf-some/cloud-project
ALERT_EMAIL ?=

.PHONY: bootstrap plan
bootstrap:
	@AWS_PROFILE='$(AWS_PROFILE)' REPO='$(REPO)' ALERT_EMAIL='$(ALERT_EMAIL)' ./bootstrap.sh apply

# Read-only: show what a rerun would change. Needs the bucket to exist.
plan:
	@AWS_PROFILE='$(AWS_PROFILE)' REPO='$(REPO)' ALERT_EMAIL='$(ALERT_EMAIL)' ./bootstrap.sh plan
