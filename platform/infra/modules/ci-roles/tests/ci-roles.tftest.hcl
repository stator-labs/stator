# Mocked-provider tests for the ci-roles module: one run per trust condition and per deny,
# with no AWS credentials.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "333333333333" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
}

variables {
  name_prefix       = "stator-ci"
  oidc_provider_arn = "arn:aws:iam::333333333333:oidc-provider/token.actions.githubusercontent.com"
  github_sub_prefix = "repo:owner@1/repo@2"
  workflow_refs = {
    plan   = "owner/repo/.github/workflows/plan.yml@refs/heads/main"
    apply  = "owner/repo/.github/workflows/apply.yml@refs/heads/main"
    reaper = "owner/repo/.github/workflows/reaper.yml@refs/heads/main"
  }
  state_bucket_arn        = "arn:aws:s3:::state"
  terminal_state_prefixes = ["labs-bootstrap"]
  boundary_arn            = "arn:aws:iam::333333333333:policy/stator/stator-boundary"
  protected_role_arns     = ["arn:aws:iam::333333333333:role/stator/stator-apply"]
}

run "names_paths_and_sessions" {
  command = plan

  assert {
    condition     = toset([for r in aws_iam_role.this : r.name]) == toset(["stator-ci-plan-pr", "stator-ci-plan-main", "stator-ci-apply", "stator-ci-reaper"])
    error_message = "Exactly four presets, named <prefix>-<preset>."
  }

  assert {
    condition     = alltrue([for r in aws_iam_role.this : r.path == "/stator/platform/" && r.max_session_duration == 3600])
    error_message = "Every CI role sits under /stator/platform/ with 1-hour sessions."
  }

  assert {
    condition     = aws_iam_role.this["reaper"].permissions_boundary == var.boundary_arn && aws_iam_role.this["apply"].permissions_boundary == null
    error_message = "The reaper carries the boundary."
  }
}

run "trust_pins_aud_sub_and_workflow" {
  command = plan

  assert {
    condition = alltrue([for k, d in data.aws_iam_policy_document.trust :
      one([for c in one(d.statement).condition : c.values if c.variable == "token.actions.githubusercontent.com:aud"]) == tolist(["sts.amazonaws.com"])
    ])
    error_message = "Every trust policy checks aud."
  }

  assert {
    condition = (
      one([for c in one(data.aws_iam_policy_document.trust["plan-pr"].statement).condition : c.values if c.variable == "token.actions.githubusercontent.com:sub"]) == tolist(["repo:owner@1/repo@2:pull_request"])
      && one([for c in one(data.aws_iam_policy_document.trust["plan-main"].statement).condition : c.values if c.variable == "token.actions.githubusercontent.com:sub"]) == tolist(["repo:owner@1/repo@2:ref:refs/heads/main"])
      && one([for c in one(data.aws_iam_policy_document.trust["apply"].statement).condition : c.values if c.variable == "token.actions.githubusercontent.com:sub"]) == tolist(["repo:owner@1/repo@2:environment:aws-apply", "repo:owner@1/repo@2:environment:aws-apply-auto"])
    )
    error_message = "plan-pr trusts PRs, plan-main trusts main, apply trusts only its environments."
  }

  assert {
    condition = (
      one([for c in one(data.aws_iam_policy_document.trust["apply"].statement).condition : c.values if c.variable == "token.actions.githubusercontent.com:job_workflow_ref"]) == tolist([var.workflow_refs.apply])
      && one([for c in one(data.aws_iam_policy_document.trust["plan-pr"].statement).condition : c.values if c.variable == "token.actions.githubusercontent.com:job_workflow_ref"]) == tolist([var.workflow_refs.plan])
      && one([for c in one(data.aws_iam_policy_document.trust["reaper"].statement).condition : c.values if c.variable == "token.actions.githubusercontent.com:job_workflow_ref"]) == tolist([var.workflow_refs.reaper])
    )
    error_message = "Every preset pins its reusable workflow, apply included."
  }

  assert {
    condition     = alltrue([for k, d in data.aws_iam_policy_document.trust : alltrue([for c in one(d.statement).condition : c.test == "StringEquals"])])
    error_message = "Trust conditions use StringEquals only, never StringLike."
  }
}

run "plan_pr_cannot_read_plans_or_terminal_state_or_lock" {
  command = plan

  assert {
    condition = (
      one(data.aws_iam_policy_document.plan_pr_deny.statement).effect == "Deny"
      && one(data.aws_iam_policy_document.plan_pr_deny.statement).resources == toset(["arn:aws:s3:::state/plans/*"])
    )
    error_message = "plan-pr must be denied saved plans."
  }

  assert {
    condition = (
      [for s in data.aws_iam_policy_document.state_read.statement : s if s.sid == "NoTerminalState"][0].effect == "Deny"
      && [for s in data.aws_iam_policy_document.state_read.statement : s if s.sid == "NoTerminalState"][0].resources == toset(["arn:aws:s3:::state/labs-bootstrap/*"])
    )
    error_message = "No plan role may read terminal-stack state."
  }

  assert {
    condition     = alltrue([for s in data.aws_iam_policy_document.state_read.statement : s.effect == "Deny" || !contains(s.actions, "s3:PutObject")])
    error_message = "The shared state-read policy grants no writes, so plan-pr cannot take or delete a lock."
  }
}

run "plan_main_writes_only_saved_plans" {
  command = plan

  assert {
    condition     = [for s in data.aws_iam_policy_document.plans_write.statement : s if s.sid == "SavePlans"][0].resources == toset(["arn:aws:s3:::state/plans/*"])
    error_message = "plan-main may write under plans/ only."
  }
}

run "apply_iam_is_scoped_and_protects_pipeline" {
  command = plan

  assert {
    condition = (
      [for s in data.aws_iam_policy_document.iam_scoped.statement : s if s.sid == "WorkloadRolesWithBoundary"][0].resources == toset(["arn:aws:iam::333333333333:role/stator/workload/*"])
      && one([for s in data.aws_iam_policy_document.iam_scoped.statement : s if s.sid == "WorkloadRolesWithBoundary"][0].condition).values == tolist([var.boundary_arn])
    )
    error_message = "apply may create roles only under the workload path and only with the boundary."
  }

  assert {
    condition = alltrue([for a in [
      "arn:aws:iam::333333333333:role/stator/platform/*",
      var.boundary_arn,
      var.oidc_provider_arn,
      "arn:aws:iam::333333333333:role/stator/stator-apply",
    ] : contains([for s in data.aws_iam_policy_document.iam_scoped.statement : s if s.sid == "ProtectPipeline"][0].resources, a)])
    error_message = "apply must deny IAM changes to CI roles, the boundary, the OIDC provider and protected legacy roles."
  }

  assert {
    condition     = [for s in data.aws_iam_policy_document.iam_scoped.statement : s if s.sid == "KeepBoundary"][0].effect == "Deny"
    error_message = "apply must never remove a permissions boundary."
  }

  assert {
    condition     = toset([for s in data.aws_iam_policy_document.iam_scoped.statement : s if s.sid == "ProtectPlansAndTerminalState"][0].resources) == toset(["arn:aws:s3:::state/plans/*", "arn:aws:s3:::state/labs-bootstrap/*"])
    error_message = "apply must not write saved plans or terminal-stack state."
  }
}

run "rejects_name_based_sub_prefix" {
  command = plan

  variables {
    github_sub_prefix = "repo:owner/repo"
  }

  expect_failures = [var.github_sub_prefix]
}

run "rejects_branch_other_than_main" {
  command = plan

  variables {
    workflow_refs = {
      plan   = "owner/repo/.github/workflows/plan.yml@refs/heads/feature"
      apply  = "owner/repo/.github/workflows/apply.yml@refs/heads/main"
      reaper = "owner/repo/.github/workflows/reaper.yml@refs/heads/main"
    }
  }

  expect_failures = [var.workflow_refs]
}
