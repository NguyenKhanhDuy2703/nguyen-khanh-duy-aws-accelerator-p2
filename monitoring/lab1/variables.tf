variable "aws_region" {
  description = "AWS Region để deploy tài nguyên"
  type        = string
  default     = "us-east-1"
}

variable "alert_email" {
  description = "Email nhận cảnh báo từ SNS"
  type        = string
  default     = "YOUR_EMAIL@gmail.com"
}

variable "ami_id" {
  description = "AMI ID cho EC2 instance (Amazon Linux 2023)"
  type        = string
  default     = "ami-0c02fb55d7c4a08a0"
}
