# Mocked-provider tests for platform/infra/labs-bootstrap (STAT-36 Step B).
# Verifies OIDC job_workflow_ref pinning, /stator/ naming, reaper boundary,
# state bucket protection, and pipeline self-edit denies with no AWS creds.

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

run "plan_role_pins_pull_request_and_reusable_main_workflow" {
  command = plan

  assert {
    condition     = aws_iam_role.plan.name == "stator-plan" && aws_iam_role.plan.path == "/stator/" && aws_iam_role.plan.max_session_duration == 3600
    error_message = "stator-plan must sit under /stator/ with a 1-hour max session."
  }

  assert {
    condition = (
      one([for c in one(data.aws_iam_policy_document.trust_plan.statement).condition : c.values
      if c.variable == "token.actions.githubusercontent.com:sub"])
      == tolist(["repo:owner@1/repo@2:pull_request"])
    )
    error_message = "stator-plan must trust pull_request subjects only."
  }

  assert {
    condition = (
      one([for c in one(data.aws_iam_policy_document.trust_plan.statement).condition : c.values
      if c.variable == "token.actions.githubusercontent.com:job_workflow_ref"])
      == tolist(["stator-labs/stator/.github/workflows/tofu-plan.yml@refs/heads/main"])
    )
    error_message = "stator-plan must pin job_workflow_ref to the reusable plan workflow on main."
  }
}

run "main_plan_role_pins_main_pushes_and_writes_only_saved_plans" {
  command = plan

  assert {
    condition     = aws_iam_role.plan_main.name == "stator-plan-main" && aws_iam_role.plan_main.path == "/stator/"
    error_message = "stator-plan-main must sit under /stator/."
  }

  assert {
    condition = (
      one([for c in one(data.aws_iam_policy_document.trust_plan_main.statement).condition : c.values
      if c.variable == "token.actions.githubusercontent.com:sub"])
      == tolist(["repo:owner@1/repo@2:ref:refs/heads/main"])
    )
    error_message = "stator-plan-main must trust pushes to main only."
  }

  assert {
    condition = (
      one([for c in one(data.aws_iam_policy_document.trust_plan_main.statement).condition : c.values
      if c.variable == "token.actions.githubusercontent.com:job_workflow_ref"])
      == tolist(["stator-labs/stator/.github/workflows/tofu-plan.yml@refs/heads/main"])
    )
    error_message = "stator-plan-main must pin job_workflow_ref to the reusable plan workflow on main."
  }

  assert {
    condition = (
      one(data.aws_iam_policy_document.plan_main_save.statement).actions == toset(["s3:PutObject"])
      && one(data.aws_iam_policy_document.plan_main_save.statement).resources == toset(["arn:aws:s3:::stator-tfstate-222222222222/plans/*"])
    )
    error_message = "stator-plan-main may write under plans/ only."
  }

  assert {
    condition = contains(
      [for s in data.aws_iam_policy_document.apply_iam.statement : s if s.sid == "ProtectPipeline" && s.effect == "Deny"][0].resources,
      "arn:aws:iam::222222222222:role/stator/stator-plan-main"
    )
    error_message = "stator-apply must explicitly deny modifying stator-plan-main."
  }
}

run "apply_role_trusts_environment_and_protects_pipeline_and_state" {
  command = plan

  assert {
    condition     = aws_iam_role.apply.name == "stator-apply" && aws_iam_role.apply.path == "/stator/"
    error_message = "stator-apply must use the /stator/ path and stator- prefix."
  }

  assert {
    condition = (
      one([for c in one(data.aws_iam_policy_document.trust_apply.statement).condition : c.values
      if c.variable == "token.actions.githubusercontent.com:sub"])
      == tolist(["repo:owner@1/repo@2:environment:aws-apply"])
    )
    error_message = "stator-apply must trust only the aws-apply environment."
  }

  assert {
    condition = contains(
      [for s in data.aws_iam_policy_document.apply_iam.statement : s if s.sid == "ProtectPipeline" && s.effect == "Deny"][0].resources,
      "arn:aws:iam::222222222222:role/stator/stator-reaper"
    )
    error_message = "stator-apply must explicitly deny modifying stator-reaper."
  }

  assert {
    condition = contains(
      [for s in data.aws_iam_policy_document.apply_iam.statement : s if s.sid == "KeepBoundary" && s.effect == "Deny"][0].actions,
      "iam:DeleteRolePermissionsBoundary"
    )
    error_message = "stator-apply must explicitly deny removing permissions boundaries."
  }
}

run "reaper_pins_main_workflow_and_carries_boundary" {
  command = plan

  assert {
    condition     = aws_iam_role.reaper.name == "stator-reaper" && aws_iam_role.reaper.path == "/stator/" && aws_iam_role.reaper.permissions_boundary != null
    error_message = "stator-reaper must sit under /stator/ and carry stator-boundary."
  }

  assert {
    condition = (
      one([for c in one(data.aws_iam_policy_document.trust_reaper.statement).condition : c.values
      if c.variable == "token.actions.githubusercontent.com:job_workflow_ref"])
      == tolist(["stator-labs/stator/.github/workflows/reaper.yml@refs/heads/main"])
    )
    error_message = "stator-reaper must pin job_workflow_ref to reaper.yml on main."
  }

  assert {
    condition = (
      one(data.aws_iam_policy_document.reaper.statement).actions == toset(["tag:GetResources"])
    )
    error_message = "stator-reaper must hold read-only tag:GetResources only."
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

run "rejects_non_main_plan_workflow_ref" {
  command = plan

  variables {
    plan_job_workflow_ref = "stator-labs/stator/.github/workflows/tofu-plan.yml@refs/heads/feature"
  }

  expect_failures = [var.plan_job_workflow_ref]
}
