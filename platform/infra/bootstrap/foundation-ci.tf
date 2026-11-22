# Tightly scoped management-account CI roles for `platform/infra/foundation`.
#
# Unlike labs (`PowerUserAccess` under SCPs), `stator-foundation-apply` has NO PowerUserAccess:
# it grants only the 7 foundation services and carries explicit Denies on closing accounts,
# disabling SCPs, stopping CloudTrail, deleting state/trail buckets, or touching its own IAM/OIDC.

data "aws_iam_policy_document" "trust_foundation_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${var.github_sub_prefix}:pull_request",
        "${var.github_sub_prefix}:ref:refs/heads/main",
      ]
    }
  }
}

data "aws_iam_policy_document" "trust_foundation_apply" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${var.github_sub_prefix}:environment:${var.foundation_apply_environment}"]
    }
  }
}

resource "aws_iam_role" "foundation_plan" {
  name                 = "stator-foundation-plan"
  path                 = local.iam_path
  description          = "GitHub Actions read-only plan role for platform/infra/foundation."
  assume_role_policy   = data.aws_iam_policy_document.trust_foundation_plan.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "foundation_plan_readonly" {
  role       = aws_iam_role.foundation_plan.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "foundation_plan_state" {
  statement {
    sid       = "ListFoundationState"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
  statement {
    sid       = "ReadFoundationState"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/foundation/*"]
  }
  statement {
    sid       = "WriteFoundationLockfile"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/foundation/*.tflock"]
  }
}

resource "aws_iam_role_policy" "foundation_plan_state" {
  name   = "foundation-state-read"
  role   = aws_iam_role.foundation_plan.id
  policy = data.aws_iam_policy_document.foundation_plan_state.json
}

# ---------------------------------------------------------------- foundation apply role

data "aws_iam_policy_document" "foundation_apply" {
  # checkov:skip=CKV_AWS_356:Organizations, Cost Explorer, Budgets, SSO and Access Analyzer actions do not support resource-level ARNs for account/org-wide operations; hard Denies below bound destructive actions.
  # checkov:skip=CKV_AWS_288:Scoped to the 7 foundation services; no arbitrary data exfiltration actions.
  # checkov:skip=CKV_AWS_289:IAM writes are restricted solely to role/runway/runway-budget-kill-switch; DenySelfAndPipelineEscalation blocks all pipeline/OIDC/boundary roles.
  # checkov:skip=CKV_AWS_290:Write actions are limited to the 7 foundation services and explicit S3/SNS/Events/IAM ARNs.
  # checkov:skip=CKV_AWS_355:Same: organization-level APIs require "*".

  statement {
    sid       = "FoundationStateList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "FoundationStateReadWrite"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/foundation/*"]
  }

  statement {
    sid = "ReadFoundationMetadata"
    actions = [
      "iam:Get*",
      "iam:List*",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ManageFoundationOrgAndCostServices"
    actions = [
      "organizations:*",
      "access-analyzer:*",
      "budgets:*",
      "ce:*",
      "sso:*",
      "identitystore:*",
      "cloudtrail:*",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "ManageRootSignInAlert"
    actions = ["sns:*", "events:*"]
    resources = [
      "arn:${local.partition}:sns:us-east-1:${local.account_id}:runway-root-sign-in",
      "arn:${local.partition}:sns:us-east-1:${local.account_id}:runway-root-sign-in:*",
      "arn:${local.partition}:events:us-east-1:${local.account_id}:rule/runway-root-sign-in",
    ]
  }

  statement {
    sid     = "ManageTrailBucketConfig"
    actions = ["s3:*"]
    resources = [
      "arn:${local.partition}:s3:::runway-org-trail-${local.account_id}",
      "arn:${local.partition}:s3:::runway-org-trail-${local.account_id}/*",
    ]
  }

  statement {
    sid = "ManageKillSwitchRoleOnly"
    actions = [
      "iam:CreateRole",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PassRole",
    ]
    resources = ["${local.iam_arn}:role/runway/runway-budget-kill-switch"]
  }

  statement {
    sid    = "DenyDestructiveOrgActions"
    effect = "Deny"
    actions = [
      "organizations:DeleteOrganization",
      "organizations:LeaveOrganization",
      "organizations:CloseAccount",
      "organizations:RemoveAccountFromOrganization",
      "organizations:DisablePolicyType",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyAuditErasure"
    effect = "Deny"
    actions = [
      "cloudtrail:DeleteTrail",
      "cloudtrail:StopLogging",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyStateAndTrailBucketDestruction"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
    ]
    resources = [
      aws_s3_bucket.state.arn,
      "arn:${local.partition}:s3:::runway-org-trail-${local.account_id}",
    ]
  }

  statement {
    sid     = "DenySelfAndPipelineEscalation"
    effect  = "Deny"
    actions = ["iam:*"]
    resources = [
      aws_iam_role.plan.arn,
      aws_iam_role.apply.arn,
      aws_iam_policy.apply_iam.arn,
      aws_iam_policy.boundary.arn,
      aws_iam_openid_connect_provider.github.arn,
      aws_iam_role.foundation_plan.arn,
      "${local.iam_arn}:role/runway/stator-foundation-apply",
      "${local.iam_arn}:policy/runway/stator-foundation-apply",
    ]
  }
}

resource "aws_iam_role" "foundation_apply" {
  name                 = "stator-foundation-apply"
  path                 = local.iam_path
  description          = "GitHub Actions on main, environment ${var.foundation_apply_environment}: scoped tofu apply for platform/infra/foundation."
  assume_role_policy   = data.aws_iam_policy_document.trust_foundation_apply.json
  max_session_duration = 3600
}

resource "aws_iam_policy" "foundation_apply" {
  name        = "stator-foundation-apply"
  path        = local.iam_path
  description = "Least-privilege foundation apply policy with explicit Denies on account closure, trail erasure and self-escalation."
  policy      = data.aws_iam_policy_document.foundation_apply.json
}

resource "aws_iam_role_policy_attachment" "foundation_apply" {
  role       = aws_iam_role.foundation_apply.name
  policy_arn = aws_iam_policy.foundation_apply.arn
}
