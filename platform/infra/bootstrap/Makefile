# The one manual step in Stator. Run once on Yaaf's Mac; safe to rerun.
#   aws sso login --profile stator   (stator = your Identity Center profile)
#   make bootstrap
# The logic lives in bootstrap.sh: macOS ships make 3.81, which has no .ONESHELL,
# and the exported AWS credentials must survive from one command to the next.

AWS_PROFILE ?= stator

.PHONY: bootstrap plan
bootstrap:
	@AWS_PROFILE='$(AWS_PROFILE)' ./bootstrap.sh apply

# Read-only: show what a rerun would change. Needs the bucket to exist.
plan:
	@AWS_PROFILE='$(AWS_PROFILE)' ./bootstrap.sh plan
