output "macie_account_id" {
  description = "Macie account resource ID"
  value       = aws_macie2_account.this.id
}

output "classification_job_id" {
  description = "Macie classification job ID"
  value       = aws_macie2_classification_job.scan_sensitive_data.id
}

output "classification_job_arn" {
  description = "Macie classification job ARN"
  value       = aws_macie2_classification_job.scan_sensitive_data.job_arn
}
