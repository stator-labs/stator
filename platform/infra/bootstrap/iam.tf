# ---------------------------------------------------------------- plan role

resource "aws_iam_role" "plan" {
  name                 = "runway-plan"
  path                 = local.iam_path
  description          = "GitHub Actions on pull requests: tofu plan only."
  assume_role_policy   = data.aws_iam_policy_document.trust_plan.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "plan_state" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }
  statement {
    # `tofu plan` takes the S3 lock too. Only *.tflock objects are writable.
    sid       = "WriteLockfile"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "tofu-state"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state.json
}

# ---------------------------------------------------------------- apply role

# PowerUserAccess has no IAM writes. These statements add IAM writes for
# roles and policies under /runway/ only, and every new role must carry the
# boundary below, so nothing the apply role creates can exceed it.
data "aws_iam_policy_document" "apply_iam" {
  # checkov:skip=CKV_AWS_356:IAM reads need "*" so tofu can refresh any role or policy; reads cannot change anything.
  statement {
    # PowerUserAccess has no IAM reads. tofu needs them to refresh state.
    sid       = "ReadIam"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }

  statement {
    sid = "RunwayRolesWithBoundary"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = ["${local.iam_arn}:role/runway/*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.boundary.arn]
    }
  }

  statement {
    sid = "ManageRunwayRoles"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PassRole",
    ]
    resources = ["${local.iam_arn}:role/runway/*"]
  }

  statement {
    sid = "ManageRunwayPolicies"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = ["${local.iam_arn}:policy/runway/*"]
  }

  statement {
    sid = "ManageRunwayInstanceProfiles"
    actions = [
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
    ]
    resources = ["${local.iam_arn}:instance-profile/runway/*"]
  }

  # The pipeline must not be able to change itself or its guardrails.
  statement {
    sid    = "ProtectPipeline"
    effect = "Deny"
    actions = [
      "iam:*",
    ]
    resources = [
      aws_iam_role.plan.arn,
      "${local.iam_arn}:role/runway/runway-apply",
      "${local.iam_arn}:policy/runway/runway-apply-iam",
      aws_iam_policy.boundary.arn,
      aws_iam_openid_connect_provider.github.arn,
    ]
  }

  statement {
    sid       = "KeepBoundary"
    effect    = "Deny"
    actions   = ["iam:DeleteRolePermissionsBoundary"]
    resources = ["*"]
  }

  statement {
    sid    = "ProtectStateBucket"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:PutBucketVersioning",
      "s3:PutLifecycleConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketOwnershipControls",
    ]
    resources = [aws_s3_bucket.state.arn]
  }
}

resource "aws_iam_role" "apply" {
  name                 = "runway-apply"
  path                 = local.iam_path
  description          = "GitHub Actions on main, environment ${var.apply_environment}: tofu apply."
  assume_role_policy   = data.aws_iam_policy_document.trust_apply.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "apply_poweruser" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_policy" "apply_iam" {
  name        = "runway-apply-iam"
  path        = local.iam_path
  description = "IAM writes for runway-apply, limited to /runway/ with a permissions boundary."
  policy      = data.aws_iam_policy_document.apply_iam.json
}

resource "aws_iam_role_policy_attachment" "apply_iam" {
  role       = aws_iam_role.apply.name
  policy_arn = aws_iam_policy.apply_iam.arn
}

# ---------------------------------------------------------------- boundary

# Every role the apply role creates must carry this boundary. It caps them at
# PowerUser minus IAM writes, and keeps them away from the state bucket.
data "aws_iam_policy_document" "boundary" {
  # checkov:skip=CKV_AWS_356:A boundary is a ceiling, not a grant; "*" with NotAction mirrors PowerUserAccess.
  # checkov:skip=CKV_AWS_107:A boundary grants nothing by itself; real grants come from each role's own policies.
  # checkov:skip=CKV_AWS_108:Same: ceiling only.
  # checkov:skip=CKV_AWS_109:Same: ceiling only.
  # checkov:skip=CKV_AWS_110:Same: ceiling only. IAM writes are excluded, so roles under it cannot escalate.
  # checkov:skip=CKV_AWS_111:Same: ceiling only.
  statement {
    sid         = "PowerUserCeiling"
    not_actions = ["iam:*", "organizations:*", "account:*"]
    resources   = ["*"]
  }
  statement {
    sid       = "IamReadAndServiceLinkedRoles"
    actions   = ["iam:Get*", "iam:List*", "iam:CreateServiceLinkedRole"]
    resources = ["*"]
  }
  statement {
    sid       = "PassRunwayRoles"
    actions   = ["iam:PassRole"]
    resources = ["${local.iam_arn}:role/runway/*"]
  }
  statement {
    sid     = "NoStateAccess"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "boundary" {
  name        = "runway-boundary"
  path        = local.iam_path
  description = "Permissions boundary for every role created by runway-apply."
  policy      = data.aws_iam_policy_document.boundary.json
}
