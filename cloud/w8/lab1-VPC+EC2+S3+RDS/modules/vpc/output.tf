output "vpc_id" {
  description = "ID of the VPC"
    value = aws_vpc.main.id
}
output "vpc_name"{
    description = "Name of the VPC"
        value = var.vpc_name
}
output "public_subnet_ids" {
  description = "Map of public subnet IDs by availability zone"
    value = { for az, subnet in aws_subnet.vpc_subnet_public : az => subnet.id }
}
output "private_subnet_ids" {
  description = "Map of private subnet IDs by availability zone"
    value = { for az, subnet in aws_subnet.vpc_subnet_private : az => subnet.id }
}
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
    value = aws_internet_gateway.vpc_igw.id
}
output "public_route_table_id" {
  description = "ID of the public route table"
    value = aws_route_table.vpc_public_rt.id
}