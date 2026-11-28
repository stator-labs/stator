# Four CI roles for one (repository, account): plan-pr, plan-main, apply and reaper.
# Every trust policy checks aud, the exact immutable sub and the exact reusable workflow on main,
# so only that workflow file, as merged on main, can assume a role (IaC platform v2).

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  iam_arn        = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}"
  oidc           = "token.actions.githubusercontent.com"
  workload_trail = trimprefix(var.workload_path, "/")
  platform_trail = trimprefix(var.path, "/")
  terminal_state = [for p in var.terminal_state_prefixes : "${var.state_bucket_arn}/${trimsuffix(p, "/")}/*"]

  presets = {
    plan-pr = {
      subs        = ["${var.github_sub_prefix}:pull_request"]
      workflow    = var.workflow_refs.plan
      description = "Pull request plans: read-only, no lock, cannot read saved plans or terminal-stack state."
      managed     = "ReadOnlyAccess"
      boundary    = false
    }
    plan-main = {
      subs        = ["${var.github_sub_prefix}:ref:refs/heads/main"]
      workflow    = var.workflow_refs.plan
      description = "Plans on main: read-only plus state lock and saved plans under plans/."
      managed     = "ReadOnlyAccess"
      boundary    = false
    }
    apply = {
      subs        = [for e in var.apply_environments : "${var.github_sub_prefix}:environment:${e}"]
      workflow    = var.workflow_refs.apply
      description = "Applies saved plans on main: PowerUser plus IAM under ${var.workload_path} with the boundary."
      managed     = "PowerUserAccess"
      boundary    = false
    }
    reaper = {
      subs        = ["${var.github_sub_prefix}:ref:refs/heads/main"]
      workflow    = var.workflow_refs.reaper
      description = "Nightly reaper on main: finds tagged ephemeral resources."
      managed     = null
      boundary    = true
    }
  }
}

data "aws_iam_policy_document" "trust" {
  for_each = local.presets

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc}:sub"
      values   = each.value.subs
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc}:job_workflow_ref"
      values   = [each.value.workflow]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = local.presets

  name                 = "${var.name_prefix}-${each.key}"
  path                 = var.path
  description          = each.value.description
  assume_role_policy   = data.aws_iam_policy_document.trust[each.key].json
  permissions_boundary = each.value.boundary ? var.boundary_arn : null
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = { for k, v in local.presets : k => v if v.managed != null }

  role       = aws_iam_role.this[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value.managed}"
}
