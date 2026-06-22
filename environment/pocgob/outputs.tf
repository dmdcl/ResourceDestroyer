output "custodian_role_arn" {
  description = "ARN of the Cloud Custodian IAM execution role."
  value       = module.iam.custodian_role_arn
}

output "custodian_role_name" {
  description = "Name of the Cloud Custodian IAM execution role."
  value       = module.iam.custodian_role_name
}

output "custodian_deploy_id" {
  description = "Trigger hash of the last Cloud Custodian deployment."
  value       = module.lambda.custodian_deploy_id
}
