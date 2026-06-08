output "rds_endpoint" {
  description = "Connection endpoint (host:port) of the RDS MySQL instance"
  value       = aws_db_instance.mysql.endpoint
}

output "rds_port" {
  description = "Port of the RDS MySQL instance"
  value       = aws_db_instance.mysql.port
}

output "rds_sg_id" {
  description = "Security Group ID of the RDS instance (sg-rds)"
  value       = aws_security_group.sg-rds.id
}

output "rds_identifier" {
  description = "Identifier of the RDS instance"
  value       = aws_db_instance.mysql.identifier
}
