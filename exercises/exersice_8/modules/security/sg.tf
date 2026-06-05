resource "aws_security_group" "sg-alb" {
  name                   = "${var.vpc_name}-sg-alb"
  description            = "Security group for ALB in ${var.vpc_name}"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true  # tự revoke rules trước khi xóa SG

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.vpc_name}-sg-alb"
    Owner = var.owner
  }
}

resource "aws_security_group" "sg-ec2" {
  name                   = "${var.vpc_name}-sg-ec2"
  description            = "Security group for EC2 instances in ${var.vpc_name}"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true  # tự revoke rules trước khi xóa SG
  ingress {
    description = "Allow SSH from anywhere"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
    description     = "Allow HTTP from ALB only"
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.sg-alb.id]
    }

    egress {
    description = "Allow all outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }
  tags = {
    Name = "${var.vpc_name}-sg-ec2"
    Owner = var.owner
  }
}