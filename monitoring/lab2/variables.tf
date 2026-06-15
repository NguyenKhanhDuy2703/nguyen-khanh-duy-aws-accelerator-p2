variable "aws_region" {
  description = "AWS Region để deploy tài nguyên"
  type        = string
  default     = "us-east-1"
}

variable "alert_email" {
  description = "Email nhận cảnh báo root login"
  type        = string
  default     = "YOUR_EMAIL@gmail.com"
}
