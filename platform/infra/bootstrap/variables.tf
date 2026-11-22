variable "region" {
  description = "Region for the state bucket and every stack."
  type        = string
  default     = "us-west-2"
}

variable "github_sub_prefix" {
  description = <<-EOT
    Subject prefix of the OIDC tokens GitHub issues for the one repository allowed to assume
    the roles. It is the `sub_claim_prefix` that GitHub reports for the repo
    (`gh api repos/<owner>/<repo>/actions/oidc/customization/sub`); bootstrap.sh reads it and
    passes it in. With immutable subjects it contains the owner and repo IDs:
    repo:<owner>@<owner id>/<repo>@<repo id>. No default on purpose: a guessed value would
    silently lock the pipeline out.
  EOT
  type        = string
  nullable    = false

  validation {
    # No wildcards, no colons: the context (":pull_request", ":environment:...") is added by the trust policies.
    condition     = can(regex("^repo:[^:*?\\s]+$", var.github_sub_prefix))
    error_message = "github_sub_prefix must look like repo:<owner>/<repo> (or the ID form), with no ':' or wildcards."
  }
}

variable "apply_environment" {
  description = "GitHub environment whose jobs may assume the apply role."
  type        = string
  default     = "aws-apply"
}

variable "foundation_apply_environment" {
  description = "GitHub environment whose jobs may assume the management foundation apply role."
  type        = string
  default     = "aws-foundation-apply"
}
