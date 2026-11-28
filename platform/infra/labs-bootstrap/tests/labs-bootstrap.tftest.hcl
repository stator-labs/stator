# Mocked-provider tests for platform/infra/labs-bootstrap (STAT-36 Step B).
# Verifies the CI module wiring, the boundary and the subject prefix check with no AWS creds.
# Trust conditions and denies of the CI roles are tested in modules/ci-roles/tests.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "222222222222" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::stator-tfstate-222222222222"
    }
  }
  mock_resource "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::222222222222:oidc-provider/token.actions.githubusercontent.com"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::222222222222:role/stator/mock-role"
    }
  }
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::222222222222:policy/stator/stator-boundary"
    }
  }
}

variables {
  github_sub_prefix = "repo:owner@1/repo@2"
}

run "ci_module_is_wired_to_this_account" {
  command = plan

  assert {
    condition     = module.ci.role_names["apply"] == "stator-ci-apply" && length(module.ci.role_names) == 4
    error_message = "The module must create exactly the four stator-ci-* presets."
  }
}

run "boundary_blocks_state_bucket_and_scopes_passrole" {
  command = plan

  assert {
    condition = (
      [for s in data.aws_iam_policy_document.boundary.statement : s if s.sid == "PassStatorRoles"][0].resources
      == toset(["arn:aws:iam::222222222222:role/stator/*"])
    )
    error_message = "stator-boundary must scope iam:PassRole to /stator/*."
  }

  assert {
    condition = contains(
      [for s in data.aws_iam_policy_document.boundary.statement : s if s.sid == "NoStateAccess" && s.effect == "Deny"][0].resources,
      "arn:aws:s3:::stator-tfstate-222222222222/*"
    )
    error_message = "stator-boundary must deny S3 access to the labs state bucket."
  }
}

run "rejects_wildcard_sub_prefix" {
  command = plan

  variables {
    github_sub_prefix = "repo:owner/*"
  }

  expect_failures = [var.github_sub_prefix]
}
