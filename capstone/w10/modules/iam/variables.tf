variable "owner" {
  description = "Owner tag"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket Macie will scan"
  type        = string
}
