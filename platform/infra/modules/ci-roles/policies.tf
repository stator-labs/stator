# ---------------------------------------------------------------- state access

data "aws_iam_policy_document" "state_read" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]
  }
  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${var.state_bucket_arn}/*"]
  }
  statement {
    sid       = "NoTerminalState"
    effect    = "Deny"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = local.terminal_state
  }
}

# plan-pr runs PR code, so it gets no lock write (PR plans use -lock=false) and cannot read
# saved plans, which hold prior state and variables.
data "aws_iam_policy_document" "plan_pr_deny" {
  statement {
    sid       = "NoSavedPlans"
    effect    = "Deny"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/plans/*"]
  }
}

data "aws_iam_policy_document" "state_lock" {
  statement {
    sid       = "WriteLockfile"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/*.tflock"]
  }
}

data "aws_iam_policy_document" "plans_write" {
  statement {
    # The apply job checks each file against the SHA-256 the plan job reports.
    sid       = "SavePlans"
    actions   = ["s3:PutObject"]
    resources = ["${var.state_bucket_arn}/plans/*"]
  }
  statement {
    # Free policy checks on IAM documents in the plan, and the org tag policy for
    # tag_policy_compliance. Neither has resource-level permissions.
    sid       = "PlanChecks"
    actions   = ["access-analyzer:ValidatePolicy", "tag:ListRequiredTags"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "state_read" {
  for_each = toset(["plan-pr", "plan-main"])

  name   = "state-read"
  role   = aws_iam_role.this[each.key].id
  policy = data.aws_iam_policy_document.state_read.json
}

resource "aws_iam_role_policy" "plan_pr_deny" {
  name   = "state-deny"
  role   = aws_iam_role.this["plan-pr"].id
  policy = data.aws_iam_policy_document.plan_pr_deny.json
}

resource "aws_iam_role_policy" "state_lock" {
  name   = "state-lock"
  role   = aws_iam_role.this["plan-main"].id
  policy = data.aws_iam_policy_document.state_lock.json
}

resource "aws_iam_role_policy" "plans_write" {
  name   = "plans-write"
  role   = aws_iam_role.this["plan-main"].id
  policy = data.aws_iam_policy_document.plans_write.json
}

# ---------------------------------------------------------------- apply

# PowerUserAccess has no IAM writes. This adds IAM writes under the workload path only,
# with the boundary required on every new role, and denies everything that would let the
# pipeline change itself, its guardrails or terminal-stack state.
data "aws_iam_policy_document" "iam_scoped" {
  # checkov:skip=CKV_AWS_356:IAM reads need "*" so tofu can refresh any role or policy; reads change nothing.
  statement {
    sid       = "ReadIam"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }

  statement {
    sid       = "WorkloadRolesWithBoundary"
    actions   = ["iam:CreateRole", "iam:PutRolePermissionsBoundary"]
    resources = ["${local.iam_arn}:role/${local.workload_trail}*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [var.boundary_arn]
    }
  }

  statement {
    sid = "ManageWorkloadRoles"
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
    resources = ["${local.iam_arn}:role/${local.workload_trail}*"]
  }

  statement {
    sid = "ManageWorkloadPolicies"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = ["${local.iam_arn}:policy/${local.workload_trail}*"]
  }

  statement {
    sid = "ManageWorkloadInstanceProfiles"
    actions = [
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
    ]
    resources = ["${local.iam_arn}:instance-profile/${local.workload_trail}*"]
  }

  statement {
    sid     = "ProtectPipeline"
    effect  = "Deny"
    actions = ["iam:*"]
    resources = concat([
      "${local.iam_arn}:role/${local.platform_trail}*",
      "${local.iam_arn}:policy/${local.platform_trail}*",
      var.boundary_arn,
      var.oidc_provider_arn,
    ], var.protected_role_arns)
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
    resources = [var.state_bucket_arn]
  }

  statement {
    # Apply reads saved plans but never writes them, and never touches terminal-stack state.
    sid       = "ProtectPlansAndTerminalState"
    effect    = "Deny"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = concat(["${var.state_bucket_arn}/plans/*"], local.terminal_state)
  }
}

resource "aws_iam_role_policy" "iam_scoped" {
  name   = "iam-scoped"
  role   = aws_iam_role.this["apply"].id
  policy = data.aws_iam_policy_document.iam_scoped.json
}

# ---------------------------------------------------------------- reaper

data "aws_iam_policy_document" "tag_read" {
  # checkov:skip=CKV_AWS_356:tag:GetResources has no resource-level permissions; it reads tags only.
  statement {
    sid       = "FindTaggedResources"
    actions   = ["tag:GetResources"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "tag_read" {
  name   = "tag-read"
  role   = aws_iam_role.this["reaper"].id
  policy = data.aws_iam_policy_document.tag_read.json
}
