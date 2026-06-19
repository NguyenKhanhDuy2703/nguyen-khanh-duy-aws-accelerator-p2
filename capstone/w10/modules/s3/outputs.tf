output "bucket_id" {
  description = "S3 bucket ID (name)"
  value       = aws_s3_bucket.macie_target.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.macie_target.arn
}
