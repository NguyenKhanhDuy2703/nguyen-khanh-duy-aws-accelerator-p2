variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_name" {
  type    = string
  default = "dev-vpc"
}

variable "owner" {
  type    = string
  default = "kduy"
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "aws_ami_name" {
  type    = string
  default = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
}

variable "aws_ami_owner" {
  type    = string
  default = "099720109477"
}

variable "instance_type" {
  type    = string
  default = "t3.medium" # 2 vCPU, 4GB RAM — đủ cho minikube + 4 Pods
}

variable "bucket_name" {
  type    = string
  default = "dev-static-assets-kduy"
}
