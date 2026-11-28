output "state_bucket" {
  value = aws_s3_bucket.state.bucket
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

output "ci_role_arns" {
  description = "The CI roles (module ci-roles), by preset."
  value       = module.ci.role_arns
}
