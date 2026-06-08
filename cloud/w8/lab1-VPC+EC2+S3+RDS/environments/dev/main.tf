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

locals {
  subnets = [
    { availability_zone = "us-east-1a", public_cidr = "10.0.1.0/24", private_cidr = "10.0.101.0/24" },
    { availability_zone = "us-east-1b", public_cidr = "10.0.2.0/24", private_cidr = "10.0.102.0/24" },
  ]
}

module "vpc" {
  source     = "../../modules/vpc"
  vpc_name   = var.vpc_name
  owner      = var.owner
  cidr_block = var.cidr_block
  subnets    = local.subnets
}

module "security" {
  source   = "../../modules/security"
  vpc_name = var.vpc_name
  owner    = var.owner
  vpc_id   = module.vpc.vpc_id
}

module "storage" {
  source     = "../../modules/storage"
  bucket_name = var.bucket_name
  owner       = var.owner
}

module "compute" {
  source            = "../../modules/compute"
  aws_ami_name      = var.aws_ami_name
  aws_ami_owner     = var.aws_ami_owner
  instance_type     = var.instance_type
  subnet_id         = values(module.vpc.public_subnet_ids)[0]
  security_group_id = module.security.sg-ec2
  vpc_name          = var.vpc_name
  owner             = var.owner
}

module "database" {
  source = "../../modules/database"

  # Context từ các module khác
  vpc_name              = var.vpc_name
  owner                 = var.owner
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ec2_security_group_id = module.security.sg-ec2

  # RDS configuration
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password
  db_instance_class      = var.db_instance_class
  db_allocated_storage   = var.db_allocated_storage
  db_engine_version      = var.db_engine_version
  db_multi_az            = var.db_multi_az
  db_skip_final_snapshot = var.db_skip_final_snapshot
  db_deletion_protection = var.db_deletion_protection
}




