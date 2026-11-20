# The AWS organization: labs account, guardrails, trail, Identity Center. Yaaf applies it from
# his terminal with management-account admin credentials; CI only lints it. Steps: ../README.md, "Apply the foundation".
#   make plan     read-only
#   make apply    shows the plan and asks for "yes"

AWS_PROFILE ?= runway
export AWS_PROFILE

.PHONY: init plan apply
init:
	@bucket="runway-tfstate-$$(aws sts get-caller-identity --query Account --output text)" && \
	  tofu init -input=false -reconfigure -lockfile=readonly -backend-config="bucket=$$bucket"

plan: init
	@tofu plan -input=false

apply: init
	@tofu apply -input=false
