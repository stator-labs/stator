data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# The organization already exists (created in the console). Import it, don't create it.
import {
  to = aws_organizations_organization.this
  id = var.organization_id
}

resource "aws_organizations_organization" "this" {
  feature_set                   = "ALL"
  enabled_policy_types          = ["SERVICE_CONTROL_POLICY"]
  aws_service_access_principals = sort(var.service_access_principals)

  lifecycle {
    prevent_destroy = true
  }
}

# Centralized root access: member accounts have no root password or keys; the management
# account can open a short root session on them for the few tasks that need one.
resource "aws_iam_organizations_features" "root_access" {
  enabled_features = ["RootCredentialsManagement", "RootSessions"]
  depends_on       = [aws_organizations_organization.this]
}

resource "aws_organizations_organizational_unit" "labs" {
  name      = "runway-labs"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_account" "labs" {
  name                       = "runway-labs"
  email                      = var.labs_account_email
  parent_id                  = aws_organizations_organizational_unit.labs.id
  iam_user_access_to_billing = "DENY"
  # Closing an account is a 90-day, mostly one-way step: never as a side effect of a destroy.
  close_on_deletion = false

  lifecycle {
    prevent_destroy = true
    # AWS does not return these after creation; without this every plan shows a replace.
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}
