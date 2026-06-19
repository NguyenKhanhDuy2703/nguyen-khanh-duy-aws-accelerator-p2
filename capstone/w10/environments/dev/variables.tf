variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Owner tag applied to all resources"
  type        = string
  default     = "capstone-w11"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# ─── S3 ───────────────────────────────────────────────────────────────────────
variable "bucket_name" {
  description = "S3 bucket name for Macie to scan (must be globally unique)"
  type        = string
  # Set in terraform.tfvars — e.g. "capstone-w11-macie-target-<yourname>"
}

# ─── Macie ────────────────────────────────────────────────────────────────────
variable "finding_publishing_frequency" {
  description = "How often Macie publishes findings: FIFTEEN_MINUTES | ONE_HOUR | SIX_HOURS"
  type        = string
  default     = "FIFTEEN_MINUTES"
}

variable "job_type" {
  description = "Classification job type: ONE_TIME | SCHEDULED"
  type        = string
  default     = "ONE_TIME"
}

# ─── Notifications ────────────────────────────────────────────────────────────
variable "notification_email" {
  description = "Email address to receive Macie alert notifications"
  type        = string
  sensitive   = true
  # Set in terraform.tfvars — never commit this value
}
