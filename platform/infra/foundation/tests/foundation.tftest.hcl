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
  mock_resource "aws_organizations_organizational_unit" {
    defaults = { id = "ou-mock-11111111" }
  }
  mock_resource "aws_organizations_account" {
    defaults = { id = "222222222222" }
  }
  mock_resource "aws_organizations_policy" {
    defaults = { id = "p-mock1111" }
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
