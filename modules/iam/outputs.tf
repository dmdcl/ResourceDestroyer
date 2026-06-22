output "custodian_role_arn" {
  description = "ARN of the IAM role assumed by Cloud Custodian Lambda functions."
  value       = aws_iam_role.custodian_execution.arn
}

output "custodian_role_name" {
  description = "Name of the IAM role assumed by Cloud Custodian Lambda functions."
  value       = aws_iam_role.custodian_execution.name
}