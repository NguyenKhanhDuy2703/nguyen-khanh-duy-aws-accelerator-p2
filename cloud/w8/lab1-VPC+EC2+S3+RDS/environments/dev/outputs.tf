output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Map of public subnet IDs by AZ"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Map of private subnet IDs by AZ"
  value       = module.vpc.private_subnet_ids
}

output "security_group_ec2_id" {
  description = "Security Group ID for EC2 instances"
  value       = module.security.sg-ec2
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = module.compute.ec2_instance_id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.compute.ec2_public_ip
}

output "s3_bucket_name" {
  description = "Name of the S3 static assets bucket"
  value       = module.storage.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 static assets bucket"
  value       = module.storage.bucket_arn
}

output "rds_endpoint" {
  description = "RDS MySQL connection endpoint"
  value       = module.database.rds_endpoint
}

output "rds_port" {
  description = "RDS MySQL port"
  value       = module.database.rds_port
}

output "rds_sg_id" {
  description = "Security Group ID of the RDS instance"
  value       = module.database.rds_sg_id
}
