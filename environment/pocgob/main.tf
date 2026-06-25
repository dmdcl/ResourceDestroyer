terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

 # Configure the backend for state storage
  backend "s3" {
    bucket       = "terraformstatefilesacces2025"
    key          = "cloud-custodian/environment/pocgob/terraform.tfstate" # Variables are not allowed here
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # Enables state locking
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

module "notifications" {
  source      = "../../modules/notifications"
  project     = var.project
  environment = var.environment
}

module "iam" {
  source = "../../modules/iam"

  project                = var.project
  environment            = var.environment
  sqs_queue_arn          = module.notifications.sqs_queue_arn
  terraform_state_bucket = var.terraform_state_bucket
}

module "lambda" {
  source = "../../modules/lambda"

  aws_region           = var.region
  project              = var.project
  environment          = var.environment
  mark_role_arn        = module.iam.mark_role_arn
  cleanup_role_arn     = module.iam.cleanup_role_arn
  mailer_role_arn      = module.iam.mailer_role_arn
  sns_topic_arn        = module.notifications.sns_topic_arn
  sqs_queue_url        = module.notifications.sqs_queue_url
  alert_email          = var.alert_email
  sender_email         = var.sender_email
  policy_dir           = "${path.module}/../../policies/resources"
  mailer_template_path = "../../policies/mailer.yml"
  custodian_bin        = var.custodian_bin
}
