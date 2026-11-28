# ---------------------------------------------------------------- boundary

# Every lab role created by stator-ci-apply carries this boundary. It caps them at
# PowerUser minus IAM/org/account writes and keeps them off the state bucket.
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
    sid       = "PassStatorRoles"
    actions   = ["iam:PassRole"]
    resources = ["${local.iam_arn}:role/stator/*"]
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
  name        = "stator-boundary"
  path        = local.iam_path
  description = "Permissions boundary for every role created by stator-ci-apply in the labs account."
  policy      = data.aws_iam_policy_document.boundary.json
}
