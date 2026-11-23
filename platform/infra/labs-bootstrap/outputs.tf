output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "plan_role_arn" {
  value = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  value = aws_iam_role.apply.arn
}

output "reaper_role_arn" {
  value = aws_iam_role.reaper.arn
}

output "boundary_arn" {
  value = aws_iam_policy.boundary.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "region" {
  value = var.region
}
