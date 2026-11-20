# The one manual step in Stator. Run once on Yaaf's Mac; safe to rerun.
#   aws sso login --profile stator && gh auth login   (stator = your Identity Center profile)
#   make bootstrap ALERT_EMAIL=<your alert email>
# ALERT_EMAIL can also come from the environment. It becomes an Actions secret.
# Never commit it or store it as a variable: the repo is public.
# The logic lives in bootstrap.sh: macOS ships make 3.81, which has no .ONESHELL,
# and the exported AWS credentials must survive from one command to the next.

AWS_PROFILE ?= stator
REPO        ?= stator-labs/stator
ALERT_EMAIL ?=

.PHONY: bootstrap plan
bootstrap:
	@AWS_PROFILE='$(AWS_PROFILE)' REPO='$(REPO)' ALERT_EMAIL='$(ALERT_EMAIL)' ./bootstrap.sh apply

# Read-only: show what a rerun would change. Needs the bucket to exist.
plan:
	@AWS_PROFILE='$(AWS_PROFILE)' REPO='$(REPO)' ALERT_EMAIL='$(ALERT_EMAIL)' ./bootstrap.sh plan
