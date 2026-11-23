output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "plan_role_arn" {
  value = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  value = aws_iam_role.apply.arn
}

output "foundation_plan_role_arn" {
  value = aws_iam_role.foundation_plan.arn
}

output "foundation_apply_role_arn" {
  value = aws_iam_role.foundation_apply.arn
}

output "region" {
  value = var.region
}
