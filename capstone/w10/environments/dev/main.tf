terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# ─── S3 Bucket + Upload Test Data ─────────────────────────────────────────────
module "s3" {
  source      = "../../modules/s3"
  bucket_name = var.bucket_name
  owner       = var.owner
  env         = var.env
}

# ─── IAM Role for Macie ────────────────────────────────────────────────────────
module "iam" {
  source     = "../../modules/iam"
  owner      = var.owner
  bucket_arn = module.s3.bucket_arn
}

# ─── Amazon Macie + Classification Job ────────────────────────────────────────
module "macie" {
  source = "../../modules/macie"

  owner                        = var.owner
  aws_account_id               = data.aws_caller_identity.current.account_id
  target_bucket_name           = module.s3.bucket_id
  finding_publishing_frequency = var.finding_publishing_frequency
  job_type                     = var.job_type
}

# ─── Notifications (EventBridge + SNS + Email) ────────────────────────────────
module "notifications" {
  source = "../../modules/notifications"

  owner              = var.owner
  notification_email = var.notification_email
}
