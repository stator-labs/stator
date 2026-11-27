# IaC platform v2 CI roles (task 6). They sit next to the legacy stator-plan, stator-apply and
# stator-reaper roles until pipeline v2 switches to them (task 8); task 9 deletes the legacy ones.

module "ci" {
  source = "../modules/ci-roles"

  name_prefix             = "stator-ci"
  oidc_provider_arn       = aws_iam_openid_connect_provider.github.arn
  github_sub_prefix       = var.github_sub_prefix
  workflow_refs           = var.ci_workflow_refs
  state_bucket_arn        = aws_s3_bucket.state.arn
  terminal_state_prefixes = ["labs-bootstrap"]
  boundary_arn            = aws_iam_policy.boundary.arn

  protected_role_arns = [
    aws_iam_role.plan.arn,
    aws_iam_role.apply.arn,
    aws_iam_role.reaper.arn,
    aws_iam_policy.apply_iam.arn,
  ]
}
