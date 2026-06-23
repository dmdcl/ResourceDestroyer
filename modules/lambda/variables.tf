variable "custodian_bin" {
  description = "Absolute path to the custodian binary. Required when running inside a virtualenv."
  type        = string
  default     = "custodian"
}

variable "aws_region" {
  description = "AWS region where Cloud Custodian Lambda functions are deployed."
  type        = string
}

variable "project" {
  description = "Project name used in resource naming and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, stage, prod)."
  type        = string
}

variable "custodian_role_arn" {
  description = "ARN of the IAM role Cloud Custodian Lambda functions assume."
  type        = string
}

variable "custodian_role_name" {
  description = "Name of the IAM role Cloud Custodian Lambda functions assume; used to prevent self-deletion in IAM policies."
  type        = string
}

variable "policy_file_path" {
  description = "Absolute path to the Cloud Custodian policy YAML file."
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic used for client infrastructure notifications."
  type        = string
}

variable "sqs_queue_url" {
  description = "URL of the SQS queue for the mailer."
  type        = string
}

variable "mailer_template_path" {
  description = "Absolute path to the mailer template YAML file."
  type        = string
}

variable "alert_email" {
  description = "Central email address to receive all resource deletion alerts."
  type        = string
}

variable "sender_email" {
  
}