output "mark_role_arn" {
  description = "ARN of the mark-phase IAM role (read + tag only)."
  value       = aws_iam_role.custodian_mark.arn
}

output "mark_role_name" {
  description = "Name of the mark-phase IAM role."
  value       = aws_iam_role.custodian_mark.name
}

output "cleanup_role_arn" {
  description = "ARN of the cleanup-phase IAM role (destructive actions only)."
  value       = aws_iam_role.custodian_cleanup.arn
}

output "cleanup_role_name" {
  description = "Name of the cleanup-phase IAM role."
  value       = aws_iam_role.custodian_cleanup.name
}

output "mailer_role_arn" {
  description = "ARN of the mailer IAM role (SQS consume + SES send only)."
  value       = aws_iam_role.custodian_mailer.arn
}

output "mailer_role_name" {
  description = "Name of the mailer IAM role."
  value       = aws_iam_role.custodian_mailer.name
}

# ---------------------------------------------------------------------------
# Backwards-compat aliases — remove once all callers use split role outputs
# ---------------------------------------------------------------------------
output "custodian_role_arn" {
  description = "Deprecated: use mark_role_arn or cleanup_role_arn."
  value       = aws_iam_role.custodian_mark.arn
}

output "custodian_role_name" {
  description = "Deprecated: use mark_role_name or cleanup_role_name."
  value       = aws_iam_role.custodian_mark.name
}
