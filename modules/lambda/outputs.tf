output "custodian_deploy_id" {
  description = "Trigger hash of the last Cloud Custodian deployment; changes when policy or role ARN changes."
  value       = null_resource.custodian_deploy.id
}
