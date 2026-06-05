terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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
  source         = "../../modules/compute"
  aws_ami_name   = var.aws_ami_name
  aws_ami_owner  = var.aws_ami_owner
  instance_type  = var.instance_type
  subnet_id      = values(module.vpc.public_subnet_ids)[0]
  ec2_security_group_id = module.security.sg-ec2
  alb_security_group_id = module.security.sg-alb
  vpc_name       = var.vpc_name
  owner          = var.owner
  subnet_ids     = values(module.vpc.public_subnet_ids)
  vpc_id         = module.vpc.vpc_id
}

