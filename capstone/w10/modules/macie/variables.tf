variable "owner" {
  description = "Owner tag"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "target_bucket_name" {
  description = "Name of the S3 bucket to scan with Macie"
  type        = string
}

variable "finding_publishing_frequency" {
  description = "How often Macie publishes findings: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS"
  type        = string
  default     = "FIFTEEN_MINUTES"
}

variable "job_type" {
  description = "Classification job type: ONE_TIME or SCHEDULED"
  type        = string
  default     = "ONE_TIME"
}
