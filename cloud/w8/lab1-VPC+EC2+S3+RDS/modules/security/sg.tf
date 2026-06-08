resource "aws_security_group" "sg-ec2" {
  name = "${var.vpc_name}-sg-ec2"
  description = "Security group for EC2 instances in ${var.vpc_name}"
  vpc_id = var.vpc_id
  ingress {
    description = "Allow SSH from anywhere"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
    description = "Allow HTTP from anywhere"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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