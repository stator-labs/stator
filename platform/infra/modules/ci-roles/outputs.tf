output "role_arns" {
  description = "Role ARN per preset: plan-pr, plan-main, apply, reaper."
  value       = { for k, r in aws_iam_role.this : k => r.arn }
}

output "role_names" {
  description = "Role name per preset."
  value       = { for k, r in aws_iam_role.this : k => r.name }
}
