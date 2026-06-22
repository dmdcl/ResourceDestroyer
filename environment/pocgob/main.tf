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
  region = var.region
  profile = var.profile
}

module "iam" {
  source = "../../modules/iam"

  project     = var.project
  environment = var.environment
}

module "lambda" {
  source = "../../modules/lambda"

  aws_region          = var.region
  project             = var.project
  environment         = var.environment
  custodian_role_arn  = module.iam.custodian_role_arn
  custodian_role_name = module.iam.custodian_role_name
  policy_file_path    = "../../policies/policy.yml"
  custodian_bin = var.custodian_bin
}