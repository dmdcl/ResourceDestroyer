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

variable "mark_role_arn" {
  description = "ARN of the mark-phase IAM role (read + tag only)."
  type        = string
}

variable "cleanup_role_arn" {
  description = "ARN of the cleanup-phase IAM role (destructive actions only)."
  type        = string
}

variable "mailer_role_arn" {
  description = "ARN of the mailer IAM role (SQS consume + SES send only)."
  type        = string
}

variable "policy_dir" {
  description = "Path to the directory containing per-resource Cloud Custodian policy YAML files."
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
  description = "Verified SES email address used as the mailer From address."
  type        = string
}
