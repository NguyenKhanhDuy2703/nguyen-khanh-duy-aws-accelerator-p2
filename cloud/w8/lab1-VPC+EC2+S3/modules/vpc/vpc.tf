resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  tags = {
    Name = var.vpc_name
    Owner = var.owner
  }
}
resource "aws_subnet" "vpc_subnet_public" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr
  availability_zone = var.availability_zone
  tags = {
    Name = "${var.vpc_name}-public-subnet"
    Owner = var.owner
  }
  
}
resource "aws_subnet" "vpc_subnet_private" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr
  availability_zone = var.availability_zone
  tags = {
    Name = "${var.vpc_name}-private-subnet"
    Owner = var.owner
  }
}
resource "aws_internet_gateway" "vpc_igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.vpc_name}-igw"
    Owner = var.owner
  }
}
resource "aws_route_table" "vpc_public_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.vpc_name}-public-rt"
    Owner = var.owner
  }
}
resource "aws_route_table_association" "vpc_public_rt_assoc" {
  subnet_id = aws_subnet.vpc_subnet_public.id
  route_table_id = aws_route_table.vpc_public_rt.id
}
resource "aws_route" "vpc_public_rt_internet_access" {
  route_table_id = aws_route_table.vpc_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.vpc_igw.id

}
