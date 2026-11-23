# Mocked-provider tests for platform/infra/bootstrap.
# Verifies OIDC trust subjects, session durations, state bucket protection, and the
# explicit Deny guardrails on stator-foundation-apply with no AWS credentials.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::runway-tfstate-111111111111"
    }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111111111111:role/runway/mock-role"
    }
  }
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::111111111111:policy/runway/mock-policy"
    }
  }
}

variables {
  github_sub_prefix = "repo:owner@1/repo@2"
}

run "foundation_apply_has_no_poweruser_and_lasts_one_hour" {
  command = plan

  assert {
    condition     = aws_iam_role.foundation_apply.path == "/runway/" && aws_iam_role.foundation_apply.max_session_duration == 3600
    error_message = "stator-foundation-apply must sit under /runway/ with 1-hour sessions."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.foundation_apply.role == "stator-foundation-apply"
    error_message = "stator-foundation-apply must attach only the scoped foundation policy."
  }
}

run "foundation_plan_state_is_scoped_to_foundation_prefix_only" {
  command = plan

  assert {
    condition = (
      [for s in data.aws_iam_policy_document.foundation_plan_state.statement : s if s.sid == "ReadFoundationState"][0].resources
      == toset(["arn:aws:s3:::runway-tfstate-111111111111/foundation/*"])
    )
    error_message = "stator-foundation-plan may read only foundation/* in the state bucket."
  }

  assert {
    condition = (
      [for s in data.aws_iam_policy_document.foundation_plan_state.statement : s if s.sid == "WriteFoundationLockfile"][0].resources
      == toset(["arn:aws:s3:::runway-tfstate-111111111111/foundation/*.tflock"])
    )
    error_message = "stator-foundation-plan may write only foundation/*.tflock lockfiles."
  }
}

run "foundation_apply_trusts_only_aws_foundation_apply_environment" {
  command = plan

  assert {
    condition = (
      one([for c in one(data.aws_iam_policy_document.trust_foundation_apply.statement).condition : c.values
      if c.variable == "token.actions.githubusercontent.com:sub"])
      == tolist(["repo:owner@1/repo@2:environment:aws-foundation-apply"])
    )
    error_message = "stator-foundation-apply must trust only the aws-foundation-apply GitHub environment."
  }
}

run "foundation_apply_explicitly_denies_account_closure_trail_stop_and_self_edit" {
  command = plan

  assert {
    condition = contains(
      [for s in data.aws_iam_policy_document.foundation_apply.statement : s if s.sid == "DenyDestructiveOrgActions" && s.effect == "Deny"][0].actions,
      "organizations:CloseAccount"
    )
    error_message = "stator-foundation-apply must explicitly deny organizations:CloseAccount."
  }

  assert {
    condition = toset(
      [for s in data.aws_iam_policy_document.foundation_apply.statement : s if s.sid == "DenyAuditErasure" && s.effect == "Deny"][0].actions
    ) == toset(["cloudtrail:DeleteTrail", "cloudtrail:StopLogging"])
    error_message = "stator-foundation-apply must explicitly deny deleting or stopping CloudTrail."
  }

  assert {
    condition = contains(
      [for s in data.aws_iam_policy_document.foundation_apply.statement : s if s.sid == "DenySelfAndPipelineEscalation" && s.effect == "Deny"][0].resources,
      "arn:aws:iam::111111111111:role/runway/stator-foundation-apply"
    )
    error_message = "stator-foundation-apply must explicitly deny modifying its own IAM role."
  }
}

run "rejects_a_wildcard_oidc_subject" {
  command = plan

  variables {
    github_sub_prefix = "repo:owner/*"
  }

  expect_failures = [var.github_sub_prefix]
}
