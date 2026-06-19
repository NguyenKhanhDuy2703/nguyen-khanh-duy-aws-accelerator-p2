data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─── SNS Topic ────────────────────────────────────────────────────────────────
resource "aws_sns_topic" "macie_alerts" {
  name = "${var.owner}-macie-alerts"

  tags = {
    Name  = "${var.owner}-macie-alerts"
    Owner = var.owner
  }
}

# SNS topic policy — allow EventBridge to publish
resource "aws_sns_topic_policy" "macie_alerts_policy" {
  arn    = aws_sns_topic.macie_alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid    = "AllowEventBridgePublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.macie_alerts.arn]
  }

  statement {
    sid    = "AllowAccountRootPublish"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "sns:Publish",
      "sns:Subscribe",
      "sns:GetTopicAttributes",
      "sns:SetTopicAttributes",
      "sns:AddPermission",
      "sns:RemovePermission",
      "sns:DeleteTopic",
      "sns:ListSubscriptionsByTopic",
    ]
    resources = [aws_sns_topic.macie_alerts.arn]
  }
}

# ─── Email Subscription ───────────────────────────────────────────────────────
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.macie_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ─── EventBridge Rule — Macie Findings ───────────────────────────────────────
resource "aws_cloudwatch_event_rule" "macie_finding" {
  name        = "${var.owner}-macie-finding-rule"
  description = "Trigger on any Amazon Macie finding"

  # Pattern matches all Macie finding events
  event_pattern = jsonencode({
    source      = ["aws.macie"]
    detail-type = ["Macie Finding"]
  })

  tags = {
    Name  = "${var.owner}-macie-finding-rule"
    Owner = var.owner
  }
}

# ─── EventBridge Rule — High Severity Only (optional second rule) ─────────────
resource "aws_cloudwatch_event_rule" "macie_finding_high" {
  name        = "${var.owner}-macie-finding-high-rule"
  description = "Trigger on HIGH severity Amazon Macie findings only"

  event_pattern = jsonencode({
    source      = ["aws.macie"]
    detail-type = ["Macie Finding"]
    detail = {
      severity = {
        description = ["High"]
      }
    }
  })

  tags = {
    Name  = "${var.owner}-macie-finding-high-rule"
    Owner = var.owner
  }
}

# ─── EventBridge Target → SNS (all findings) ─────────────────────────────────
resource "aws_cloudwatch_event_target" "sns_all_findings" {
  rule      = aws_cloudwatch_event_rule.macie_finding.name
  target_id = "MacieSNSAllFindings"
  arn       = aws_sns_topic.macie_alerts.arn

  # Transform the raw event into a readable email
  input_transformer {
    input_paths = {
      finding_type     = "$.detail.type"
      severity         = "$.detail.severity.description"
      bucket_name      = "$.detail.resourcesAffected.s3Bucket.name"
      object_key       = "$.detail.resourcesAffected.s3Object.key"
      account_id       = "$.detail.accountId"
      region           = "$.region"
      finding_id       = "$.detail.id"
      created_at       = "$.detail.createdAt"
      data_identifiers = "$.detail.classificationDetails.result.sensitiveData[0].category"
    }
    input_template = <<-EOT
      {
        "subject": "🚨 Amazon Macie Alert — Sensitive Data Detected",
        "message": "Amazon Macie has detected sensitive data in your S3 bucket.\n\n=== Finding Details ===\nFinding Type: <finding_type>\nSeverity:     <severity>\nAccount:      <account_id>\nRegion:       <region>\nCreated At:   <created_at>\n\n=== Affected Resource ===\nS3 Bucket:    <bucket_name>\nObject Key:   <object_key>\n\n=== Sensitive Data ===\nData Category: <data_identifiers>\n\n=== Action Required ===\nPlease review this finding in the AWS Macie Console:\nhttps://console.aws.amazon.com/macie/home?region=<region>#/findings?itemId=<finding_id>\n\nFinding ID: <finding_id>"
      }
    EOT
  }
}

# ─── EventBridge Target → SNS (high severity only) ───────────────────────────
resource "aws_cloudwatch_event_target" "sns_high_findings" {
  rule      = aws_cloudwatch_event_rule.macie_finding_high.name
  target_id = "MacieSNSHighFindings"
  arn       = aws_sns_topic.macie_alerts.arn

  input_transformer {
    input_paths = {
      finding_type = "$.detail.type"
      severity     = "$.detail.severity.description"
      bucket_name  = "$.detail.resourcesAffected.s3Bucket.name"
      object_key   = "$.detail.resourcesAffected.s3Object.key"
      finding_id   = "$.detail.id"
      region       = "$.region"
    }
    input_template = <<-EOT
      {
        "subject": "🔴 URGENT — HIGH Severity Macie Finding",
        "message": "[HIGH SEVERITY] Amazon Macie detected sensitive data!\n\nFinding Type: <finding_type>\nSeverity:     <severity>\nBucket:       <bucket_name>\nObject:       <object_key>\n\nView in Console:\nhttps://console.aws.amazon.com/macie/home?region=<region>#/findings?itemId=<finding_id>"
      }
    EOT
  }
}
