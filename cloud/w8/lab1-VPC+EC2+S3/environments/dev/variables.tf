variable "cidr_block" {
	description = "CIDR block for the VPC"
	type        = string
	default     = "10.0.0.0/16"
}

variable "availability_zone" {
	description = "Availability zone for the dev environment"
	type        = string
	default     = "us-east-1a"
}

variable "public_subnet_cidr" {
	description = "CIDR block for the public subnet"
	type        = string
	default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
	description = "CIDR block for the private subnet"
	type        = string
	default     = "10.0.2.0/24"
}

variable "aws_ami_name" {
	description = "The name filter of the AWS AMI to use for the EC2 instance"
	type        = string
	default     = "amzn2-ami-hvm-*"
}

variable "instance_type" {
	description = "The type of the EC2 instance"
	type        = string
	default     = "t3.micro"
}

variable "bucket_name" {
	description = "The name of the S3 bucket"
	type        = string
	default     = "dev-lab1-bucket-kduy"
}
variable "owner" {
    description = "The owner of the resources"
    type        = string
    default     = "dev-team"
}
variable "aws_ami_owner" {
    description = "The owner of the AWS AMI to use for the EC2 instance"
    type        = string
	default     = "137112412989"
}