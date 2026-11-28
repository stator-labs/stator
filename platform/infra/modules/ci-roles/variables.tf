variable "name_prefix" {
  description = "Prefix for every role name, for example \"stator-ci\" gives stator-ci-plan-pr."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name_prefix))
    error_message = "name_prefix must be lowercase letters, digits and hyphens, at most 31 characters."
  }
}

variable "path" {
  description = "IAM path for the CI roles. Guardrail SCPs protect everything under it."
  type        = string
  default     = "/stator/platform/"

  validation {
    condition     = can(regex("^/([a-z0-9-]+/)+$", var.path))
    error_message = "path must look like /a/b/ (lowercase, leading and trailing slash)."
  }
}

variable "workload_path" {
  description = "IAM path under which the apply role may create roles, policies and instance profiles."
  type        = string
  default     = "/stator/workload/"

  validation {
    condition     = can(regex("^/([a-z0-9-]+/)+$", var.workload_path))
    error_message = "workload_path must look like /a/b/ (lowercase, leading and trailing slash)."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider in this account."
  type        = string
  nullable    = false
}

variable "github_sub_prefix" {
  description = <<-EOT
    sub_claim_prefix GitHub reports for the repo (gh api repos/<owner>/<repo>/actions/oidc/customization/sub).
    Must be the immutable ID form repo:<owner>@<owner id>/<repo>@<repo id>, which survives renames
    and cannot be re-registered by someone else.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^repo:[^:*?\\s/@]+@[0-9]+/[^:*?\\s/@]+@[0-9]+$", var.github_sub_prefix))
    error_message = "github_sub_prefix must be the immutable form repo:<owner>@<id>/<repo>@<id>, with no wildcards."
  }
}

variable "workflow_refs" {
  description = "Exact job_workflow_ref each preset trusts: plan (plan-pr and plan-main), apply and reaper. All on refs/heads/main."
  type = object({
    plan   = string
    apply  = string
    reaper = string
  })
  nullable = false

  validation {
    condition = alltrue([
      for r in values(var.workflow_refs) :
      can(regex("^[^:*?\\s]+/\\.github/workflows/[^:*?\\s/]+\\.ya?ml@refs/heads/main$", r))
    ])
    error_message = "Each workflow ref must pin one file under .github/workflows/ at @refs/heads/main, with no wildcards."
  }
}

variable "apply_environments" {
  description = "GitHub environments whose jobs may assume the apply role (manual and auto lanes)."
  type        = list(string)
  default     = ["aws-apply", "aws-apply-auto"]
  nullable    = false

  validation {
    condition     = length(var.apply_environments) > 0 && alltrue([for e in var.apply_environments : can(regex("^[a-z0-9-]+$", e))])
    error_message = "apply_environments must be lowercase names with no wildcards."
  }
}

variable "state_bucket_arn" {
  description = "ARN of the OpenTofu state bucket in this account."
  type        = string
  nullable    = false
}

variable "terminal_state_prefixes" {
  description = "State key prefixes of terminal-only stacks. No CI role may read or write them."
  type        = list(string)
  nullable    = false
}

variable "boundary_arn" {
  description = "Permissions boundary every role the apply role creates must carry. The reaper carries it too."
  type        = string
  nullable    = false
}

variable "protected_role_arns" {
  description = "Extra role or policy ARNs the apply role must never touch (for example legacy pipeline roles)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "max_session_duration" {
  description = "Session length in seconds for every CI role."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 900 && var.max_session_duration <= 3600
    error_message = "max_session_duration must be between 900 and 3600 seconds."
  }
}
