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
variable "security_group_id" {
  description = "The ID of the security group to associate with the EC2 instance"
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