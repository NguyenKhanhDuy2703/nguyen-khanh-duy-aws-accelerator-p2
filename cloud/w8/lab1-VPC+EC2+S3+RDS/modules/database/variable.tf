# === Context từ các module khác ===

variable "vpc_name" {
  description = "Name of the VPC (used for resource naming and tagging)"
  type        = string
}

variable "owner" {
  description = "Owner tag applied to all resources in this module"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy RDS into"
  type        = string
}

variable "private_subnet_ids" {
  description = "Map of private subnet IDs keyed by AZ — from module.vpc.private_subnet_ids. Must contain at least 2 entries in different AZs."
  type        = map(string)
}

variable "ec2_security_group_id" {
  description = "Security Group ID of EC2 instances — used as source for RDS port 3306 ingress rule"
  type        = string
}

# === RDS Configuration ===

variable "db_name" {
  description = "Name of the initial database created on the RDS instance"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the RDS MySQL instance"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for the RDS MySQL instance. Must be supplied at runtime — never hardcode."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance type (e.g. db.t3.micro for dev, db.r6g.large for prod)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for the RDS instance in GB"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment — false for dev, true for production"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on destroy — true for dev convenience, false for production safety"
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Enable deletion protection on the RDS instance — false for dev, true for production"
  type        = bool
  default     = false
}
