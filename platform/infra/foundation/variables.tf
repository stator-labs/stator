# Personal values go in foundation.auto.tfvars, which git ignores. Never in code: the repo is public.

variable "organization_id" {
  description = "ID of the existing AWS organization (o-...), used in the trail bucket policy. `aws organizations describe-organization`."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^o-[a-z0-9]{10,32}$", var.organization_id))
    error_message = "organization_id must look like o-abc123defg."
  }
}

variable "service_access_principals" {
  description = <<-EOT
    Services with trusted access to the organization. Must include every service that has it
    today, or the apply turns it off: compare with
    `aws organizations list-aws-service-access-for-organization` before the first apply.
  EOT
  type        = list(string)
  default = [
    "access-analyzer.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "iam.amazonaws.com", # centralized root access
    "sso.amazonaws.com",
  ]
}

variable "labs_account_email" {
  description = "Root email of the new labs account. Must be unused by any AWS account; a plus address works."
  type        = string
  sensitive   = true
  nullable    = false
}

variable "alert_email" {
  description = "Where root sign-in, budget and cost anomaly alerts go. Never commit it: the repo is public."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be an email address."
  }
}

variable "sso_user" {
  description = "Your IAM Identity Center user."
  type = object({
    user_name   = string
    given_name  = string
    family_name = string
    email       = string
  })
  sensitive = true
  nullable  = false
}

variable "allowed_regions" {
  description = "Regions the labs account may use. Global services are exempt."
  type        = list(string)
  default     = ["us-west-2", "us-east-1"]
}

variable "allowed_instance_types" {
  description = "EC2 instance types the labs account may launch (wildcards allowed)."
  type        = list(string)
  default     = ["t3.micro", "t3.small", "t3.medium", "t4g.micro", "t4g.small", "t4g.medium", "t4g.large", "m7g.large", "m7i.large"]
}
