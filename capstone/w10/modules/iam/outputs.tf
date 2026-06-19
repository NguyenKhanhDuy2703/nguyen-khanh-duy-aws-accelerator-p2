output "macie_role_arn" {
  description = "ARN of the Macie classification IAM role"
  value       = aws_iam_role.macie_classification.arn
}

output "macie_role_name" {
  description = "Name of the Macie classification IAM role"
  value       = aws_iam_role.macie_classification.name
}
