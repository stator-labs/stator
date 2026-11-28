# The CI roles (IaC platform v2): stator-ci-plan-pr, -plan-main, -apply and -reaper under
# /stator/platform/, each trusting one reusable workflow on main.

module "ci" {
  source = "../modules/ci-roles"

  name_prefix             = "stator-ci"
  oidc_provider_arn       = aws_iam_openid_connect_provider.github.arn
  github_sub_prefix       = var.github_sub_prefix
  workflow_refs           = var.ci_workflow_refs
  state_bucket_arn        = aws_s3_bucket.state.arn
  terminal_state_prefixes = ["labs-bootstrap"]
  boundary_arn            = aws_iam_policy.boundary.arn
}
