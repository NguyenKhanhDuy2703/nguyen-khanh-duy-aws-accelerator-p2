output "sg-ec2" {
  description = "The security group of the ec2"
  value = aws_security_group.sg-ec2.id
}

output "sg-alb" {
  description = "The security group of the alb"
  value = aws_security_group.sg-alb.id
}