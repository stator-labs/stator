# Terminal-only bootstrap for the labs account (STAT-36 Step B).
#   aws sso login --profile stator-labs && gh auth login
#   make bootstrap              # creates stator-* bucket, OIDC provider, and CI roles in labs
#   make plan                   # read-only drift check after bootstrap
#   make cutover                # points GitHub repo variables at the labs roles (after OIDC probe passes)

AWS_PROFILE ?= stator-labs
REPO        ?= stator-labs/stator

.PHONY: bootstrap plan cutover
bootstrap:
	@AWS_PROFILE='$(AWS_PROFILE)' REPO='$(REPO)' ./bootstrap.sh apply

plan:
	@AWS_PROFILE='$(AWS_PROFILE)' REPO='$(REPO)' ./bootstrap.sh plan

cutover:
	@AWS_PROFILE='$(AWS_PROFILE)' REPO='$(REPO)' ./bootstrap.sh cutover
