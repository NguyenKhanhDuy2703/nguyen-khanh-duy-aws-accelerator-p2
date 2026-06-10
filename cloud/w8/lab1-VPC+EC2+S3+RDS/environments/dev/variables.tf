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
  default = "t3.micro"
}

variable "bucket_name" {
  type    = string
  default = "dev-static-assets-kduy"
}

# === RDS MySQL Variables ===

variable "db_name" {
  description = "Name of the initial database on the RDS instance"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for RDS MySQL"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for RDS MySQL. Supply via TF_VAR_db_password or terraform.tfvars — never hardcode."
  type        = string
  sensitive   = false
}

variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment (false for dev, true for prod)"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on destroy (true for dev, false for prod)"
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Enable deletion protection on RDS (false for dev, true for prod)"
  type        = bool
  default     = false
}
