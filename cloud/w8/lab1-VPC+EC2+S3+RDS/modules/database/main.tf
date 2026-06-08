# -----------------------------------------------------------
# Security Group for RDS — allows MySQL (3306) from EC2 SG only
# -----------------------------------------------------------
resource "aws_security_group" "sg-rds" {
  name        = "${var.vpc_name}-sg-rds"
  description = "Security group for RDS MySQL in ${var.vpc_name} - allows port 3306 from EC2 only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow MySQL from EC2 security group"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ec2_security_group_id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.vpc_name}-sg-rds"
    Owner = var.owner
  }
}

# -----------------------------------------------------------
# DB Subnet Group — spans private subnets in 2 AZs
# -----------------------------------------------------------
resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "${var.vpc_name}-rds-subnet-group"
  description = "DB subnet group for ${var.vpc_name} - private subnets across 2 AZs"
  subnet_ids  = values(var.private_subnet_ids)

  tags = {
    Name  = "${var.vpc_name}-rds-subnet-group"
    Owner = var.owner
  }
}

# -----------------------------------------------------------
# RDS MySQL Instance
# Note: publicly_accessible is hardcoded false — not overridable
# -----------------------------------------------------------
resource "aws_db_instance" "mysql" {
  identifier        = "${var.vpc_name}-mysql"
  engine            = "mysql"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.sg-rds.id]

  multi_az            = var.db_multi_az
  publicly_accessible = false

  skip_final_snapshot = var.db_skip_final_snapshot
  deletion_protection = var.db_deletion_protection

  tags = {
    Name  = "${var.vpc_name}-mysql"
    Owner = var.owner
  }
}
