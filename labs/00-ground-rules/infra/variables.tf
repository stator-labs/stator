variable "alert_email" {
  description = "Address for budget and anomaly alerts. Set in CI from the Actions secret ALERT_EMAIL (the repo is public); never commit it."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be an email address."
  }
}
