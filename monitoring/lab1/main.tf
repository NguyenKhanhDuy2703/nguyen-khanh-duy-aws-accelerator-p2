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

resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "EC2-CloudWatch-Agent-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "CloudWatch-Agent-Role"
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "cloudwatch_agent_profile" {
  name = "EC2-CloudWatch-Agent-Profile"
  role = aws_iam_role.cloudwatch_agent_role.name
}

resource "aws_sns_topic" "cpu_alert_topic" {
  name         = "ec2-cpu-alert-topic"
  display_name = "EC2 CPU Alert"

  tags = {
    Name        = "EC2-CPU-Alert-Topic"
    Environment = "Lab"
    Purpose     = "CloudWatch-Alarm-Notification"
  }
}

resource "aws_sns_topic_subscription" "cpu_alert_email" {
  topic_arn = aws_sns_topic.cpu_alert_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-monitoring-lab-sg"
  description = "Security group cho EC2 monitoring lab"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EC2-Monitoring-Lab-SG"
  }
}

resource "aws_instance" "monitored_ec2" {
  ami           = var.ami_id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.cloudwatch_agent_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              
              yum install -y amazon-cloudwatch-agent stress
              
              cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CONFIG'
              {
                "metrics": {
                  "namespace": "CustomEC2Metrics",
                  "metrics_collected": {
                    "cpu": {
                      "measurement": [
                        {"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"},
                        {"name": "cpu_usage_iowait", "rename": "CPU_IOWAIT", "unit": "Percent"},
                        "cpu_time_guest"
                      ],
                      "metrics_collection_interval": 60,
                      "totalcpu": false
                    },
                    "disk": {
                      "measurement": [
                        {"name": "used_percent", "rename": "DISK_USED", "unit": "Percent"}
                      ],
                      "metrics_collection_interval": 60,
                      "resources": ["*"]
                    },
                    "mem": {
                      "measurement": [
                        {"name": "mem_used_percent", "rename": "MEM_USED", "unit": "Percent"}
                      ],
                      "metrics_collection_interval": 60
                    }
                  }
                }
              }
              CONFIG
              
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config \
                -m ec2 \
                -s \
                -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              
              systemctl enable amazon-cloudwatch-agent
              systemctl start amazon-cloudwatch-agent
              
              cat > /home/ec2-user/stress-cpu.sh <<'SCRIPT'
              #!/bin/bash
              echo "🔥 Bắt đầu stress test CPU..."
              echo "CPU sẽ tăng lên ~100% trong 10 phút (600 giây)"
              echo "CloudWatch Alarm sẽ kích hoạt sau 5 phút"
              stress --cpu 1 --timeout 600s
              echo "✅ Stress test hoàn tất!"
              SCRIPT
              chmod +x /home/ec2-user/stress-cpu.sh
              chown ec2-user:ec2-user /home/ec2-user/stress-cpu.sh
              
              cat > /home/ec2-user/check-agent-status.sh <<'SCRIPT'
              #!/bin/bash
              echo "📊 CloudWatch Agent Status:"
              sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a query -m ec2 -c default -s
              SCRIPT
              chmod +x /home/ec2-user/check-agent-status.sh
              chown ec2-user:ec2-user /home/ec2-user/check-agent-status.sh
              EOF

  tags = {
    Name        = "Monitored-EC2-Instance"
    Environment = "Lab"
    Purpose     = "CloudWatch-Monitoring-Test"
  }

  monitoring = true
}

resource "aws_cloudwatch_metric_alarm" "cpu_high_alarm" {
  alarm_name          = "ec2-cpu-utilization-high"
  alarm_description   = "Cảnh báo khi CPU EC2 vượt quá 80% liên tục trong 5 phút"
  comparison_operator = "GreaterThanThreshold"

  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
  statistic   = "Average"
  period      = 300

  threshold           = 80
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.monitored_ec2.id
  }

  alarm_actions = [
    aws_sns_topic.cpu_alert_topic.arn
  ]

  ok_actions = [
    aws_sns_topic.cpu_alert_topic.arn
  ]

  tags = {
    Name        = "EC2-CPU-High-Alarm"
    Environment = "Lab"
  }
}

output "ec2_instance_id" {
  description = "ID của EC2 instance được giám sát"
  value       = aws_instance.monitored_ec2.id
}

output "ec2_public_ip" {
  description = "Public IP của EC2 (dùng để SSH)"
  value       = aws_instance.monitored_ec2.public_ip
}

output "sns_topic_arn" {
  description = "ARN của SNS Topic"
  value       = aws_sns_topic.cpu_alert_topic.arn
}

output "cloudwatch_alarm_name" {
  description = "Tên của CloudWatch Alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_high_alarm.alarm_name
}

output "stress_test_command" {
  description = "Lệnh để chạy stress test trên EC2"
  value       = "ssh ec2-user@${aws_instance.monitored_ec2.public_ip} './stress-cpu.sh'"
}

output "important_note" {
  description = "⚠️ Lưu ý quan trọng"
  value       = "📧 KIỂM TRA EMAIL (kể cả spam) để XÁC NHẬN SNS subscription!"
}

output "cloudwatch_agent_commands" {
  description = "Lệnh kiểm tra CloudWatch Agent trên EC2"
  value = {
    check_status = "ssh ec2-user@${aws_instance.monitored_ec2.public_ip} './check-agent-status.sh'"
    view_logs    = "ssh ec2-user@${aws_instance.monitored_ec2.public_ip} 'sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log'"
  }
}
