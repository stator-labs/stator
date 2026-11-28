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

variable "ci_workflow_refs" {
  description = "Reusable workflows the CI roles trust, all on main."
  type = object({
    plan   = string
    apply  = string
    reaper = string
  })
  default = {
    plan   = "stator-labs/stator/.github/workflows/plan.yml@refs/heads/main"
    apply  = "stator-labs/stator/.github/workflows/apply.yml@refs/heads/main"
    reaper = "stator-labs/stator/.github/workflows/reaper.yml@refs/heads/main"
  }
}
