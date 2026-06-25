output "mark_role_arn" {
  description = "ARN of the Cloud Custodian mark-phase IAM role."
  value       = module.iam.mark_role_arn
}

output "mark_role_name" {
  description = "Name of the Cloud Custodian mark-phase IAM role."
  value       = module.iam.mark_role_name
}

output "cleanup_role_arn" {
  description = "ARN of the Cloud Custodian cleanup-phase IAM role."
  value       = module.iam.cleanup_role_arn
}

output "cleanup_role_name" {
  description = "Name of the Cloud Custodian cleanup-phase IAM role."
  value       = module.iam.cleanup_role_name
}

output "mailer_role_arn" {
  description = "ARN of the Cloud Custodian mailer IAM role."
  value       = module.iam.mailer_role_arn
}

output "mailer_role_name" {
  description = "Name of the Cloud Custodian mailer IAM role."
  value       = module.iam.mailer_role_name
}

output "custodian_deploy_id" {
  description = "Trigger hash of the last Cloud Custodian deployment."
  value       = module.lambda.custodian_deploy_id
}
