# outputs.tf - Values to display after Terraform finishes
#
# Like a function's return value - after `terraform apply` runs,
# these values get printed to the terminal so you can see what was created.

output "mwaa_bucket_name" {
  description = "The name of the S3 bucket for MWAA"
  value       = aws_s3_bucket.mwaa.id
}

output "mwaa_bucket_arn" {
  description = "The ARN of the S3 bucket for MWAA"
  value       = aws_s3_bucket.mwaa.arn
}

output "github_actions_role_arn" {
  description = "The ARN of the IAM role for GitHub Actions (put this in deploy.yml)"
  value       = aws_iam_role.github_actions_deploy.arn
}
