output "target_bucket_name" {
  description = "S3 bucket name being scanned by Macie"
  value       = module.s3.bucket_id
}

output "target_bucket_arn" {
  description = "S3 bucket ARN"
  value       = module.s3.bucket_arn
}

output "macie_classification_job_id" {
  description = "Macie classification job ID"
  value       = module.macie.classification_job_id
}

output "macie_classification_job_arn" {
  description = "Macie classification job ARN"
  value       = module.macie.classification_job_arn
}

output "sns_topic_arn" {
  description = "SNS topic ARN for Macie alerts"
  value       = module.notifications.sns_topic_arn
}

output "eventbridge_rule_arn" {
  description = "EventBridge rule ARN (all findings)"
  value       = module.notifications.eventbridge_rule_arn
}

output "eventbridge_rule_high_arn" {
  description = "EventBridge rule ARN (high severity only)"
  value       = module.notifications.eventbridge_rule_high_arn
}

output "macie_console_url" {
  description = "Direct link to Macie findings in AWS Console"
  value       = "https://console.aws.amazon.com/macie/home?region=us-east-1#/findings"
}
