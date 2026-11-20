# The reaper finds resources tagged runway:ephemeral=true (.github/workflows/reaper.yml).
# It can only look: tag:GetResources. Each ephemeral lab adds the delete actions for its own
# services from its own stack, on the role name "runway-reaper".

data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  # Built from names, not read from AWS, so the plan needs no extra IAM reads.
  github_oidc_arn = "arn:${local.partition}:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
  boundary_arn    = "arn:${local.partition}:iam::${local.account_id}:policy/runway/runway-boundary"
}

# Only runs on main can sign in: the schedule and manual runs. The sub for a run on main
# ends in ":ref:refs/heads/main". Pull requests (":pull_request"), other branches and
# environments do not match.
data "aws_iam_policy_document" "reaper_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${var.github_sub_prefix}:ref:refs/heads/main"]
    }
  }
}

data "aws_iam_policy_document" "reaper" {
  # checkov:skip=CKV_AWS_356:tag:GetResources has no resource-level permissions; "*" is the only valid resource, and the action only reads tags.
  statement {
    sid       = "FindTaggedResources"
    actions   = ["tag:GetResources"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "reaper" {
  name                 = "runway-reaper"
  path                 = "/runway/"
  description          = "GitHub Actions on main (nightly and manual runs): finds ephemeral resources. Reads tags only; deletes nothing."
  assume_role_policy   = data.aws_iam_policy_document.reaper_trust.json
  permissions_boundary = local.boundary_arn
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "reaper" {
  name   = "find-tagged-resources"
  role   = aws_iam_role.reaper.id
  policy = data.aws_iam_policy_document.reaper.json
}
