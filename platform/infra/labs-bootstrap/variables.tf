variable "region" {
  description = "Region for the labs state bucket and every lab stack."
  type        = string
  default     = "us-west-2"
}

variable "github_sub_prefix" {
  description = <<-EOT
    Subject prefix of the OIDC tokens GitHub issues for this repository (`sub_claim_prefix`
    from `gh api repos/<owner>/<repo>/actions/oidc/customization/sub`). With immutable subjects
    it contains owner and repo IDs: repo:<owner>@<owner id>/<repo>@<repo id>. No default on
    purpose: a guessed value would silently lock the pipeline out.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^repo:[^:*?\\s]+$", var.github_sub_prefix))
    error_message = "github_sub_prefix must look like repo:<owner>/<repo> (or the ID form), with no ':' or wildcards."
  }
}

variable "apply_environment" {
  description = "GitHub environment whose jobs may assume the labs apply role."
  type        = string
  default     = "aws-apply"
}

variable "plan_job_workflow_ref" {
  description = "Exact reusable plan workflow ref on main allowed to assume stator-plan."
  type        = string
  default     = "stator-labs/stator/.github/workflows/tofu-plan.yml@refs/heads/main"

  validation {
    condition     = can(regex("^[^:*?\\s]+/\\.github/workflows/[^:*?\\s]+\\.ya?ml@refs/heads/main$", var.plan_job_workflow_ref))
    error_message = "plan_job_workflow_ref must pin one workflow file under .github/workflows/ at @refs/heads/main with no wildcards."
  }
}

variable "reaper_job_workflow_ref" {
  description = "Exact reaper workflow ref on main allowed to assume stator-reaper."
  type        = string
  default     = "stator-labs/stator/.github/workflows/reaper.yml@refs/heads/main"

  validation {
    condition     = can(regex("^[^:*?\\s]+/\\.github/workflows/[^:*?\\s]+\\.ya?ml@refs/heads/main$", var.reaper_job_workflow_ref))
    error_message = "reaper_job_workflow_ref must pin one workflow file under .github/workflows/ at @refs/heads/main with no wildcards."
  }
}
