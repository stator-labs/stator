# Runs with no AWS access: the provider is mocked. It checks what the code plans, not what AWS accepts.
# The mock invents random strings for computed values, and AWS ARN validation rejects them,
# so the values the code feeds into ARNs are fixed below.
#
# The budget and anomaly tests moved to platform/infra/foundation/tests with the resources.

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
}

variables {
  github_sub_prefix = "repo:owner@1/repo@2"
}

run "reaper_role_is_bounded" {
  command = plan

  assert {
    condition     = aws_iam_role.reaper.path == "/runway/" && aws_iam_role.reaper.max_session_duration == 3600
    error_message = "The reaper role must sit under /runway/ with 1-hour sessions."
  }

  assert {
    condition     = endswith(aws_iam_role.reaper.permissions_boundary, ":policy/runway/runway-boundary")
    error_message = "The reaper role must carry the runway permissions boundary."
  }
}

run "rejects_a_wildcard_oidc_subject" {
  command = plan

  variables {
    github_sub_prefix = "repo:owner/*"
  }

  expect_failures = [var.github_sub_prefix]
}
