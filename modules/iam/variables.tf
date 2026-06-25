variable "project" {
  description = "Project name used in resource naming and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, stage, prod)."
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN of the SQS mailer queue; scopes notify send and mailer consume permissions."
  type        = string
}

variable "terraform_state_bucket" {
  description = "Name of the S3 bucket holding Terraform state; explicitly denied in cleanup role."
  type        = string
}
