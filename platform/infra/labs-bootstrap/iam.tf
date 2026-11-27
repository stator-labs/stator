# ---------------------------------------------------------------- plan role

resource "aws_iam_role" "plan" {
  name                 = "stator-plan"
  path                 = local.iam_path
  description          = "GitHub Actions reusable plan workflow on pull requests: tofu plan in labs only."
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

# ---------------------------------------------------------------- main plan role

# Plans each push to main and saves the plan file for the apply job (STAT-34). A separate
# role so PR code, which runs as stator-plan, can never write or replace a saved plan.
resource "aws_iam_role" "plan_main" {
  name                 = "stator-plan-main"
  path                 = local.iam_path
  description          = "GitHub Actions reusable plan workflow on pushes to main: tofu plan in labs, saves plans/."
  assume_role_policy   = data.aws_iam_policy_document.trust_plan_main.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_main_readonly" {
  role       = aws_iam_role.plan_main.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "plan_main_state" {
  name   = "tofu-state"
  role   = aws_iam_role.plan_main.id
  policy = data.aws_iam_policy_document.plan_state.json
}

data "aws_iam_policy_document" "plan_main_save" {
  statement {
    # Saved plans only. The apply job checks each file against the SHA-256 this job reports.
    sid       = "SavePlans"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.state.arn}/plans/*"]
  }
}

resource "aws_iam_role_policy" "plan_main_save" {
  name   = "save-plans"
  role   = aws_iam_role.plan_main.id
  policy = data.aws_iam_policy_document.plan_main_save.json
}

# ---------------------------------------------------------------- apply role

# In the labs account, the phase 2 guardrail SCP bounds PowerUserAccess to two
# regions, allowed instance types and zero commitments. This inline policy adds
# IAM writes under /stator/ only, with stator-boundary required on every role.
data "aws_iam_policy_document" "apply_iam" {
  # checkov:skip=CKV_AWS_356:IAM reads need "*" so tofu can refresh any role or policy; reads cannot change anything.
  statement {
    sid       = "ReadIam"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }

  statement {
    sid = "StatorRolesWithBoundary"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = ["${local.iam_arn}:role/stator/*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.boundary.arn]
    }
  }

  statement {
    sid = "ManageStatorRoles"
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
    resources = ["${local.iam_arn}:role/stator/*"]
  }

  statement {
    sid = "ManageStatorPolicies"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = ["${local.iam_arn}:policy/stator/*"]
  }

  statement {
    sid = "ManageStatorInstanceProfiles"
    actions = [
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
    ]
    resources = ["${local.iam_arn}:instance-profile/stator/*"]
  }

  # The pipeline must not be able to edit itself, the reaper, or its guardrails.
  statement {
    sid    = "ProtectPipeline"
    effect = "Deny"
    actions = [
      "iam:*",
    ]
    resources = [
      aws_iam_role.plan.arn,
      "${local.iam_arn}:role/stator/stator-plan-main",
      "${local.iam_arn}:role/stator/stator-apply",
      "${local.iam_arn}:role/stator/stator-reaper",
      "${local.iam_arn}:policy/stator/stator-apply-iam",
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
  name                 = "stator-apply"
  path                 = local.iam_path
  description          = "GitHub Actions on main, environment ${var.apply_environment}: tofu apply in labs."
  assume_role_policy   = data.aws_iam_policy_document.trust_apply.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "apply_poweruser" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_policy" "apply_iam" {
  name        = "stator-apply-iam"
  path        = local.iam_path
  description = "IAM writes for stator-apply, limited to /stator/ with a permissions boundary."
  policy      = data.aws_iam_policy_document.apply_iam.json
}

resource "aws_iam_role_policy_attachment" "apply_iam" {
  role       = aws_iam_role.apply.name
  policy_arn = aws_iam_policy.apply_iam.arn
}

# ---------------------------------------------------------------- reaper role

data "aws_iam_policy_document" "reaper" {
  # checkov:skip=CKV_AWS_356:tag:GetResources has no resource-level permissions; "*" is the only valid resource and it reads tags only.
  statement {
    sid       = "FindTaggedResources"
    actions   = ["tag:GetResources"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "reaper" {
  name                 = "stator-reaper"
  path                 = local.iam_path
  description          = "GitHub Actions on main (nightly and manual reaper runs): lists ephemeral resources in labs."
  assume_role_policy   = data.aws_iam_policy_document.trust_reaper.json
  permissions_boundary = aws_iam_policy.boundary.arn
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "reaper" {
  name   = "find-tagged-resources"
  role   = aws_iam_role.reaper.id
  policy = data.aws_iam_policy_document.reaper.json
}

# ---------------------------------------------------------------- boundary

# Every lab role created by stator-apply carries this boundary. It caps them at
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
  description = "Permissions boundary for every role created by stator-apply in the labs account."
  policy      = data.aws_iam_policy_document.boundary.json
}
