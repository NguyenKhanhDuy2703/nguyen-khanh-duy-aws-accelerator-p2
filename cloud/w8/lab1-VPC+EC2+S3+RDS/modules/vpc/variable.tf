variable "vpc_name" {
  description = "Name of the VPC"
  type = string
}
variable "owner" {
  description = "Owner created the VPC"
  type = string
}
variable "cidr_block" {
  description = "CIDR block for the VPC"
  type = string
}
variable "subnets" {
  description = "List of subnet definitions keyed by availability zone"
  type = list(object({
    availability_zone = string
    public_cidr       = string
    private_cidr      = string
  }))
}
