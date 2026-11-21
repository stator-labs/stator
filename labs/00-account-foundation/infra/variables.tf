variable "github_sub_prefix" {
  description = <<-EOT
    Subject prefix of the OIDC tokens GitHub issues for this repository (the repo variable
    OIDC_SUB_PREFIX, set by `make bootstrap`). With immutable subjects it contains the owner and
    repo IDs: repo:<owner>@<owner id>/<repo>@<repo id>. CI passes it. No default on purpose: a
    guessed value would silently lock the reaper out.
  EOT
  type        = string
  nullable    = false

  validation {
    # No wildcards, no colons: the trust policy adds the context (":ref:refs/heads/main").
    condition     = can(regex("^repo:[^:*?\\s]+$", var.github_sub_prefix))
    error_message = "github_sub_prefix must look like repo:<owner>/<repo> (or the ID form), with no ':' or wildcards."
  }
}
