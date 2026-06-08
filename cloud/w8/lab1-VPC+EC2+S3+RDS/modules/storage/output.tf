output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.s3_static_assets.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.s3_static_assets.arn
}

output "bucket_id" {
  description = "ID (name) of the S3 bucket"
  value       = aws_s3_bucket.s3_static_assets.id
}
