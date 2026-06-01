terraform {
  required_version = ">=1.10"
  
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 6.0"
    }
  }
}
provider "aws" {
    region = "us-east-1"
  }

module "vpc" {
  source = "../../modules/vpc"
  vpc_name = "dev-vpc"
  owner = "dev-team"
  cidr_block = var.cidr_block
  availability_zone = var.availability_zone
  public_subnet_cidr = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}
module "security" {
  source = "../../modules/security"
  vpc_id = module.vpc.vpc_id
  vpc_name = module.vpc.vpc_name
  owner = var.owner
}
module "compute" {
  source = "../../modules/compute"
  aws_ami_name = var.aws_ami_name
  instance_type = var.instance_type
  subnet_id = module.vpc.private_subnet_id
  security_group_id = module.security.sg-ec2
  vpc_name = module.vpc.vpc_name
  owner = var.owner
  aws_ami_owner = var.aws_ami_owner
}
module "storage" {
  source = "../../modules/storage"
  bucket_name = var.bucket_name
  owner = var.owner
}