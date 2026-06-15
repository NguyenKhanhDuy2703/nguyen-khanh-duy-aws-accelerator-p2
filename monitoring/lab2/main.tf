terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket        = "cloudtrail-root-login-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "CloudTrail-Root-Login-Bucket"
    Environment = "Lab"
    Purpose     = "Security-Monitoring"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_bucket.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail_log_group" {
  name              = "/aws/cloudtrail/root-account-monitoring"
  retention_in_days = 7

  tags = {
    Name        = "CloudTrail-Root-Monitoring-Logs"
    Environment = "Lab"
  }
}

resource "aws_iam_role" "cloudtrail_cloudwatch_role" {
  name = "CloudTrail-CloudWatch-Logs-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "CloudTrail-CloudWatch-Role"
  }
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch_policy" {
  name = "CloudTrail-CloudWatch-Logs-Policy"
  role = aws_iam_role.cloudtrail_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailCreateLogStream"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
      },
      {
        Sid    = "AWSCloudTrailPutLogEvents"
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
      }
    ]
  })
}

resource "aws_cloudtrail" "root_account_trail" {
  depends_on = [
    aws_s3_bucket_policy.cloudtrail_bucket_policy,
    aws_iam_role_policy.cloudtrail_cloudwatch_policy
  ]

  name                          = "root-account-monitoring-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch_role.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = {
    Name        = "Root-Account-Monitoring-Trail"
    Environment = "Lab"
  }
}

resource "aws_cloudwatch_log_metric_filter" "root_login_filter" {
  name           = "RootAccountLoginFilter"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_log_group.name
  pattern        = "{ $.userIdentity.type = \"Root\" && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootAccountLoginCount"
    namespace = "Security"
    value     = "1"
  }
}

resource "aws_sns_topic" "root_login_alert_topic" {
  name         = "root-account-login-alert"
  display_name = "Root Account Login Alert"

  tags = {
    Name        = "Root-Login-Alert-Topic"
    Environment = "Lab"
  }
}

resource "aws_sns_topic_subscription" "root_login_email" {
  topic_arn = aws_sns_topic.root_login_alert_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "root_login_alarm" {
  alarm_name          = "root-account-login-detected"
  alarm_description   = "CRITICAL: Root account login detected! This should almost never happen!"
  comparison_operator = "GreaterThanOrEqualToThreshold"

  metric_name = "RootAccountLoginCount"
  namespace   = "Security"
  statistic   = "Sum"
  period      = 300

  threshold           = 1
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = [
    aws_sns_topic.root_login_alert_topic.arn
  ]

  tags = {
    Name        = "Root-Login-Alarm"
    Environment = "Lab"
    Severity    = "CRITICAL"
  }
}

output "cloudtrail_name" {
  description = "CloudTrail name"
  value       = aws_cloudtrail.root_account_trail.name
}

output "s3_bucket_name" {
  description = "S3 bucket chứa CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_bucket.bucket
}

output "log_group_name" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.cloudtrail_log_group.name
}

output "metric_filter_name" {
  description = "Metric Filter name"
  value       = aws_cloudwatch_log_metric_filter.root_login_filter.name
}

output "alarm_name" {
  description = "CloudWatch Alarm name"
  value       = aws_cloudwatch_metric_alarm.root_login_alarm.alarm_name
}

output "sns_topic_arn" {
  description = "SNS Topic ARN"
  value       = aws_sns_topic.root_login_alert_topic.arn
}

output "important_notes" {
  description = "⚠️ Lưu ý quan trọng"
  value = {
    step1 = "📧 KIỂM TRA EMAIL để confirm SNS subscription"
    step2 = "⏱️ ĐỢI 2-3 phút sau terraform apply để CloudTrail bắt đầu ghi logs"
    step3 = "⚠️ LOGOUT khỏi IAM user trước khi test"
    step4 = "🔐 LOGIN vào Root Account (dùng email root + password)"
    step5 = "⏱️ ĐỢI 5-15 phút để logs xuất hiện trong CloudWatch"
    step6 = "📧 Nhận email cảnh báo khi alarm kích hoạt"
    step7 = "⚠️ LOGOUT root ngay sau khi test!"
  }
}
