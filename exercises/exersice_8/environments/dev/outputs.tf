output "vpc_id" {
  description = "ID of the VPC created by the vpc module"
  value       = module.vpc.vpc_id
}

output "security_group_ec2_id" {
  description = "EC2 security group ID"
  value       = module.security.sg-ec2
}

output "alb_dns_link" {
  value       = "http://${module.compute.alb_dns_name}"
  description = "Click vao Link nay de truy cap ung dung tu Internet qua ALB"
}
