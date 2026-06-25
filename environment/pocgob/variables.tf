variable "region" {
  description = "AWS region where all resources are deployed."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used in resource naming and tags."
  type        = string
  default     = "client-alpha"
}

variable "environment" {
  description = "Deployment environment (dev, stage, prod)."
  type        = string
  default     = "prod"
}

variable "profile" {
  description = "AWS CLI named profile to use for authentication."
  type        = string
}

variable "custodian_bin" {
  description = "Absolute path to the custodian binary. Required when running inside a virtualenv."
  type        = string
  default     = "custodian"
}

variable "alert_email" {
  description = "email to alerts"
  type        = string
  default     = "test@email.com"
}

variable "sender_email" {
  description = "Verified SES email address used as the mailer From address."
  type        = string
}

variable "terraform_state_bucket" {
  description = "Name of the S3 bucket holding Terraform state; explicitly denied in cleanup role."
  type        = string
  default     = "terraformstatefilesacces2025"
}
