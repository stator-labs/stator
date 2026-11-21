# Runs with no AWS access: both provider configurations are mocked. It checks what the code
# plans, not what AWS accepts. The mock invents random strings for computed values, and AWS ARN
# validation rejects them, so the values the code feeds into ARNs are fixed below.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
  mock_resource "aws_organizations_organization" {
    defaults = { roots = [{ id = "r-mock", arn = "arn:aws:organizations::111111111111:root/o-mock/r-mock", name = "Root", policy_types = [] }] }
  }
  mock_resource "aws_organizations_account" {
    defaults = { id = "222222222222" }
  }
  mock_resource "aws_organizations_policy" {
    defaults = { id = "p-mock1111" }
  }
  mock_resource "aws_organizations_organizational_unit" {
    defaults = { id = "ou-mock-11111111", arn = "arn:aws:organizations::111111111111:ou/o-mock/ou-mock-11111111" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111111111111:role/runway/runway-budget-kill-switch" }
  }
  mock_resource "aws_ce_anomaly_monitor" {
    defaults = { arn = "arn:aws:ce::111111111111:anomalymonitor/mock" }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:us-east-1:111111111111:runway-root-sign-in" }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:111111111111:rule/runway-root-sign-in" }
  }
  mock_resource "aws_ssoadmin_permission_set" {
    defaults = { arn = "arn:aws:sso:::permissionSet/ssoins-1111111111111111/ps-1111111111111111" }
  }
  mock_resource "aws_identitystore_user" {
    defaults = { user_id = "11111111-1111-1111-1111-111111111111" }
  }
  mock_data "aws_ssoadmin_instances" {
    defaults = {
      arns               = ["arn:aws:sso:::instance/ssoins-1111111111111111"]
      identity_store_ids = ["d-1111111111"]
    }
  }
}

mock_provider "aws" {
  alias = "us_east_1"

  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:us-east-1:111111111111:runway-root-sign-in" }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:111111111111:rule/runway-root-sign-in" }
  }
  mock_resource "aws_ssoadmin_permission_set" {
    defaults = { arn = "arn:aws:sso:::permissionSet/ssoins-1111111111111111/ps-1111111111111111" }
  }
  mock_resource "aws_identitystore_user" {
    defaults = { user_id = "11111111-1111-1111-1111-111111111111" }
  }
  mock_data "aws_ssoadmin_instances" {
    defaults = {
      arns               = ["arn:aws:sso:::instance/ssoins-1111111111111111"]
      identity_store_ids = ["d-1111111111"]
    }
  }
}

variables {
  organization_id    = "o-abc123defg"
  labs_account_email = "labs@example.com"
  alert_email        = "alerts@example.com"
  sso_user = {
    user_name   = "someone"
    given_name  = "Some"
    family_name = "One"
    email       = "someone@example.com"
  }
}

run "labs_scp_has_the_six_guardrails" {
  command = plan

  assert {
    condition = toset([for s in jsondecode(aws_organizations_policy.labs.content).Statement : s.Sid]) == toset([
      "DenyOtherRegions", "DenyCommitments", "DenyLargeInstances",
      "DenyLeavingOrganization", "DenyRoleManagerEnable", "DenyTemplateRoles",
    ])
    error_message = "The labs SCP must keep its six statements."
  }

  assert {
    condition     = alltrue([for s in jsondecode(aws_organizations_policy.labs.content).Statement : s.Effect == "Deny"])
    error_message = "Every SCP statement must be a Deny. FullAWSAccess stays attached and these carve out of it."
  }
}

run "labs_scp_limits_regions_and_instance_types" {
  command = plan

  assert {
    condition = [for s in jsondecode(aws_organizations_policy.labs.content).Statement : s
    if s.Sid == "DenyOtherRegions"][0].Condition.StringNotEquals["aws:RequestedRegion"] == ["us-west-2", "us-east-1"]
    error_message = "Only us-west-2 and us-east-1 are allowed by default."
  }

  assert {
    condition = !contains([for s in jsondecode(aws_organizations_policy.labs.content).Statement : s
    if s.Sid == "DenyLargeInstances"][0].Condition.StringNotLike["ec2:InstanceType"], "*")
    error_message = "The instance type allow-list must not contain a bare wildcard."
  }
}

run "labs_scp_blocks_commitments" {
  command = plan

  assert {
    condition = contains([for s in jsondecode(aws_organizations_policy.labs.content).Statement : s
    if s.Sid == "DenyCommitments"][0].Action, "savingsplans:CreateSavingsPlan")
    error_message = "Savings Plans must stay denied in the labs account."
  }
}

run "scp_attaches_to_the_labs_ou_not_the_root" {
  command = plan

  assert {
    condition     = aws_organizations_policy_attachment.labs.target_id == aws_organizations_organizational_unit.labs.id
    error_message = "The guardrail SCP must attach to the labs OU."
  }
}

run "organization_and_labs_account_cannot_be_destroyed_by_accident" {
  command = plan

  assert {
    condition     = aws_organizations_account.labs.close_on_deletion == false
    error_message = "A destroy must never close the labs account."
  }
}

run "trail_is_organization_wide_and_validated" {
  command = plan

  assert {
    condition     = aws_cloudtrail.org.is_organization_trail && aws_cloudtrail.org.is_multi_region_trail && aws_cloudtrail.org.enable_log_file_validation
    error_message = "The trail must cover the organization and all regions, with log file validation."
  }
}

run "trail_bucket_is_private_versioned_and_expires" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.trail.block_public_acls,
      aws_s3_bucket_public_access_block.trail.block_public_policy,
      aws_s3_bucket_public_access_block.trail.ignore_public_acls,
      aws_s3_bucket_public_access_block.trail.restrict_public_buckets,
    ])
    error_message = "The trail bucket must block all public access."
  }

  assert {
    condition     = aws_s3_bucket_versioning.trail.versioning_configuration[0].status == "Enabled"
    error_message = "The trail bucket must stay versioned."
  }

  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.trail.rule).expiration[0].days == 90
    error_message = "Trail logs must expire after 90 days to keep idle cost near $0."
  }
}

run "access_analyzer_is_external_access_only" {
  command = plan

  assert {
    condition     = aws_accessanalyzer_analyzer.org.type == "ORGANIZATION"
    error_message = "Use the organization analyzer type. Unused-access analysis is paid and stays off."
  }
}

run "root_sign_in_alert_is_in_us_east_1_and_emails" {
  command = plan

  assert {
    condition     = aws_sns_topic_subscription.root_sign_in.protocol == "email"
    error_message = "The root sign-in alert must go out by email."
  }
}

run "admin_sessions_last_one_hour_in_both_accounts" {
  command = plan

  assert {
    condition     = aws_ssoadmin_permission_set.admin.session_duration == "PT1H"
    error_message = "Admin sessions must last 1 hour."
  }

  assert {
    condition     = toset(keys(aws_ssoadmin_account_assignment.admin)) == toset(["management", "labs"])
    error_message = "The admin permission set must reach the management and labs accounts."
  }
}

run "rejects_a_malformed_organization_id" {
  command = plan

  variables {
    organization_id = "not-an-org"
  }

  expect_failures = [var.organization_id]
}

run "budgets_at_5_15_and_30" {
  command = plan

  assert {
    condition     = toset(keys(aws_budgets_budget.monthly)) == toset(["5", "15", "30"])
    error_message = "Expected budgets at $5, $15 and $30."
  }

  assert {
    condition     = alltrue([for b in aws_budgets_budget.monthly : b.limit_unit == "USD" && b.time_unit == "MONTHLY"])
    error_message = "Every budget must be monthly, in USD."
  }
}

run "only_the_top_budget_warns_on_forecast" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.monthly["5"].notification) == 1 && length(aws_budgets_budget.monthly["15"].notification) == 1
    error_message = "The $5 and $15 budgets must have the actual-spend notification only."
  }

  assert {
    condition     = length(aws_budgets_budget.monthly["30"].notification) == 2
    error_message = "The $30 budget must also warn on forecast."
  }
}

run "anomaly_alert_is_daily_email_from_1_dollar" {
  command = plan

  assert {
    condition     = aws_ce_anomaly_subscription.email.frequency == "DAILY"
    error_message = "Email subscribers can only get DAILY or WEEKLY. DAILY is the fastest."
  }

  assert {
    condition     = one(aws_ce_anomaly_subscription.email.threshold_expression[0].dimension[0].values) == "1"
    error_message = "The anomaly threshold must stay at $1."
  }
}

run "kill_switch_scp_only_denies_actions_that_start_spend" {
  command = plan

  assert {
    condition     = length(jsondecode(aws_organizations_policy.deny_new_spend.content).Statement) == 1 && jsondecode(aws_organizations_policy.deny_new_spend.content).Statement[0].Effect == "Deny"
    error_message = "The deny-new-spend SCP must be one Deny statement."
  }

  assert {
    condition = !anytrue([
      for a in local.deny_new_spend_actions : can(regex("(Delete|Terminate|Stop|Describe|List|Get|Detach|Remove|Cancel)", a))
    ])
    error_message = "The SCP must not deny deletes, stops or reads: the reaper and make nuke need them while it is on."
  }

  assert {
    condition     = length(aws_organizations_policy.deny_new_spend.content) < 5120
    error_message = "An SCP is limited to 5120 characters."
  }
}

run "kill_switch_budget_is_30_dollars_for_the_labs_account_only" {
  command = plan

  assert {
    condition     = aws_budgets_budget.labs_kill_switch.limit_amount == "30" && aws_budgets_budget.labs_kill_switch.time_unit == "MONTHLY"
    error_message = "The kill switch trips at $30 a month."
  }

  assert {
    condition     = one(aws_budgets_budget.labs_kill_switch.cost_filter).name == "LinkedAccount"
    error_message = "The kill-switch budget must be filtered to the labs account."
  }
}

run "kill_switch_action_attaches_the_scp_to_the_labs_ou_automatically" {
  command = plan

  assert {
    condition     = aws_budgets_budget_action.kill_switch.action_type == "APPLY_SCP_POLICY" && aws_budgets_budget_action.kill_switch.approval_model == "AUTOMATIC"
    error_message = "The action must attach an SCP with no approval step."
  }

  assert {
    condition     = aws_budgets_budget_action.kill_switch.notification_type == "ACTUAL" && one(aws_budgets_budget_action.kill_switch.action_threshold).action_threshold_value == 100
    error_message = "The action must fire at 100% of the $30 budget, on actual spend."
  }

  assert {
    condition = (
      one(one(aws_budgets_budget_action.kill_switch.definition).scp_action_definition).policy_id == aws_organizations_policy.deny_new_spend.id
      && one(one(one(aws_budgets_budget_action.kill_switch.definition).scp_action_definition).target_ids) == aws_organizations_organizational_unit.labs.id
    )
    error_message = "The action must attach the deny-new-spend SCP to the labs OU and nothing else."
  }
}

run "kill_switch_role_trusts_only_the_budgets_service_for_this_budget" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.kill_switch.assume_role_policy).Statement[0].Principal.Service == "budgets.amazonaws.com"
    error_message = "Only the AWS Budgets service may assume the kill-switch role."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.kill_switch.assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == "111111111111"
      && endswith(jsondecode(aws_iam_role.kill_switch.assume_role_policy).Statement[0].Condition.ArnLike["aws:SourceArn"], ":budget/runway-labs-kill-switch")
    )
    error_message = "The trust policy must name this account and this one budget."
  }
}

run "kill_switch_role_can_only_attach_or_detach_one_scp_on_one_ou" {
  command = plan

  assert {
    condition     = toset(jsondecode(aws_iam_role_policy.kill_switch.policy).Statement[0].Action) == toset(["organizations:AttachPolicy", "organizations:DetachPolicy"])
    error_message = "The role may only attach and detach policies."
  }

  assert {
    condition     = length(jsondecode(aws_iam_role_policy.kill_switch.policy).Statement[0].Resource) == 2 && !contains(jsondecode(aws_iam_role_policy.kill_switch.policy).Statement[0].Resource, "*")
    error_message = "The role must be limited to the one SCP and the labs OU."
  }
}

run "rejects_a_bad_alert_email" {
  command = plan

  variables {
    alert_email = "not-an-email"
  }

  expect_failures = [var.alert_email]
}
