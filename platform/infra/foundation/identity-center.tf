# IAM Identity Center replaces the IAM user yaaf-admin: one person, a passkey, 1-hour sessions.
# The organization instance is turned on once in the console first (it has no API); this stack
# then adds the user, one permission set, and access to both accounts. The instance lives in
# us-east-1, and an instance can't move region, so every resource here uses that provider.

data "aws_ssoadmin_instances" "this" {
  provider = aws.us_east_1
}

locals {
  sso_instance_arn  = one(data.aws_ssoadmin_instances.this.arns)
  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)
}

resource "aws_identitystore_user" "yaaf" {
  provider          = aws.us_east_1
  identity_store_id = local.identity_store_id
  user_name         = var.sso_user.user_name
  display_name      = "${var.sso_user.given_name} ${var.sso_user.family_name}"

  name {
    given_name  = var.sso_user.given_name
    family_name = var.sso_user.family_name
  }

  emails {
    value   = var.sso_user.email
    primary = true
  }
}

resource "aws_ssoadmin_permission_set" "admin" {
  provider         = aws.us_east_1
  name             = "runway-admin"
  description      = "Full access for Yaaf. 1-hour sessions."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT1H"
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  provider = aws.us_east_1
  # checkov:skip=CKV_AWS_274:This is the one human admin, signing in with a passkey for 1 hour. It replaces yaaf-admin, which has the same policy today.
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_account_assignment" "admin" {
  provider = aws.us_east_1
  for_each = {
    management = local.account_id
    labs       = aws_organizations_account.labs.id
  }

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  principal_type     = "USER"
  principal_id       = aws_identitystore_user.yaaf.user_id
  target_type        = "AWS_ACCOUNT"
  target_id          = each.value

  depends_on = [aws_ssoadmin_managed_policy_attachment.admin]
}
