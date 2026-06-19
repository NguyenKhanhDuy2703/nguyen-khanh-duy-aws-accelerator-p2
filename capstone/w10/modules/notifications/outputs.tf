output "sns_topic_arn" {
  description = "ARN of the SNS topic for Macie alerts"
  value       = aws_sns_topic.macie_alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.macie_alerts.name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule (all findings)"
  value       = aws_cloudwatch_event_rule.macie_finding.arn
}

output "eventbridge_rule_high_arn" {
  description = "ARN of the EventBridge rule (high severity only)"
  value       = aws_cloudwatch_event_rule.macie_finding_high.arn
}
