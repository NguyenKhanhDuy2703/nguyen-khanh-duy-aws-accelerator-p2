variable "bucket_name" {
  description = "Name of the S3 bucket Macie will scan"
  type        = string
}

variable "owner" {
  description = "Owner tag"
  type        = string
}

variable "env" {
  description = "Environment name (dev/prod)"
  type        = string
  default     = "dev"
}
