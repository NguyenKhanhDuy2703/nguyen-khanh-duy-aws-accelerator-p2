variable "aws_ami_name" {
  description = "The name of the AWS AMI to use for the EC2 instance"
  type = string
}
variable "instance_type" {
  description = "The type of the EC2 instance"
  type = string
}
variable "subnet_id" {
  description = "The ID of the subnet to launch the EC2 instance in"
  type = string
}
variable "ec2_security_group_id" {
  description = "The ID of the security group to associate with the EC2 instance"
  type = string
}
variable "alb_security_group_id" {
  description = "The ID of the security group to associate with the ALB"
  type = string
}
variable "vpc_name" {
  description = "The name of the VPC"
  type = string
}
variable "owner" {
  description = "The owner of the EC2 instance"
  type = string
}
variable "aws_ami_owner" {
  description = "The owner of the AWS AMI to use for the EC2 instance"
  type = string
}
variable "subnet_ids" {
  description = "The IDs of the subnets to launch the ALB in"
  type = list(string)
}
variable "vpc_id" {
  description = "The ID of the VPC to launch the ALB in"
  type = string
}