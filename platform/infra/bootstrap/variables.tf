variable "region" {
  description = "Region for the state bucket and every stack."
  type        = string
  default     = "us-west-2"
}

variable "github_repo" {
  description = "owner/name of the only repository allowed to assume the roles."
  type        = string
  default     = "yaaf-some/cloud-project"
}

variable "apply_environment" {
  description = "GitHub environment whose jobs may assume the apply role."
  type        = string
  default     = "aws-apply"
}
