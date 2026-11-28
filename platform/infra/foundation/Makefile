# The AWS organization: labs account, guardrails, trail, Identity Center. Yaaf applies it from
# his terminal with management-account admin credentials; CI only lints it. Steps: ../README.md, "Apply the foundation".
#   make plan     read-only
#   make apply    shows the plan and asks for "yes"
#   make tfvars   writes foundation.auto.tfvars from what AWS holds now (see tfvars.sh).
#                 plan and apply run it themselves when the file is missing.

AWS_PROFILE ?= stator
export AWS_PROFILE

.PHONY: init plan apply tfvars
init: foundation.auto.tfvars
	@bucket="runway-tfstate-$$(aws sts get-caller-identity --query Account --output text)" && \
	  tofu init -input=false -reconfigure -lockfile=readonly -backend-config="bucket=$$bucket"

plan: init
	@tofu plan -input=false

apply: init
	@tofu apply -input=false

tfvars:
	@bash tfvars.sh

# Rebuilt from AWS only when missing; never overwrites an existing file.
foundation.auto.tfvars:
	@bash tfvars.sh
