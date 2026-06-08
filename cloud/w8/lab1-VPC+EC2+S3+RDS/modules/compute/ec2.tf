data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.aws_ami_owner]
  filter {
    name   = "name"
    values = [var.aws_ami_name]
  }
 filter {
  name   = "architecture"
  values = ["x86_64"]
}
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  tags = {
    Name  = "${var.vpc_name}-ec2-instance"
    Owner = var.owner
  }
}