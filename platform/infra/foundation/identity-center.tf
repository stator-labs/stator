# IAM Identity Center is the only human sign-in: one person, a passkey, 1-hour sessions.
# It replaced the IAM user yaaf-admin, deleted on 2026-11-20.
# The organization instance is turned on once in the console first (it has no API); this stack
# then adds the user, the admin permission set, and access to both accounts. The instance lives in
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

# Permission sets cannot be renamed, so a rename adds the new name, you sign in with it, and a
# second change drops the old one. Remove "runway-admin" once `sso_role_name` uses stator-admin.
locals {
  admin_permission_sets = toset(["runway-admin", "stator-admin"])
  admin_accounts = {
    management = local.account_id
    labs       = aws_organizations_account.labs.id
  }
}

resource "aws_ssoadmin_permission_set" "admin" {
  provider         = aws.us_east_1
  for_each         = local.admin_permission_sets
  name             = each.key
  description      = "Full access for Yaaf. 1-hour sessions."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT1H"
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  provider = aws.us_east_1
  for_each = local.admin_permission_sets
  # checkov:skip=CKV_AWS_274:This is the one human admin, signing in with a passkey for 1 hour. It replaced yaaf-admin, which had the same policy.
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin[each.key].arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_account_assignment" "admin" {
  provider = aws.us_east_1
  for_each = {
    for pair in setproduct(local.admin_permission_sets, keys(local.admin_accounts)) :
    "${pair[0]}/${pair[1]}" => { set = pair[0], account = local.admin_accounts[pair[1]] }
  }

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin[each.value.set].arn
  principal_type     = "USER"
  principal_id       = aws_identitystore_user.yaaf.user_id
  target_type        = "AWS_ACCOUNT"
  target_id          = each.value.account

  depends_on = [aws_ssoadmin_managed_policy_attachment.admin]
}

# Keep the live runway-admin resources instead of replacing them.
moved {
  from = aws_ssoadmin_permission_set.admin
  to   = aws_ssoadmin_permission_set.admin["runway-admin"]
}

moved {
  from = aws_ssoadmin_managed_policy_attachment.admin
  to   = aws_ssoadmin_managed_policy_attachment.admin["runway-admin"]
}

moved {
  from = aws_ssoadmin_account_assignment.admin["management"]
  to   = aws_ssoadmin_account_assignment.admin["runway-admin/management"]
}

moved {
  from = aws_ssoadmin_account_assignment.admin["labs"]
  to   = aws_ssoadmin_account_assignment.admin["runway-admin/labs"]
}
