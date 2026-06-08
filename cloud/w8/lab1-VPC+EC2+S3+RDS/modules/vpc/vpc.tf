resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  tags = {
    Name = var.vpc_name
    Owner = var.owner
  }
}

locals {
  subnets_by_az = {
    for subnet in var.subnets : subnet.availability_zone => subnet
  }
}

resource "aws_subnet" "vpc_subnet_public" {
  for_each = local.subnets_by_az

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.public_cidr
  availability_zone = each.key

  tags = {
    Name  = "${var.vpc_name}-${each.key}-public-subnet"
    Owner = var.owner
  }
}

resource "aws_subnet" "vpc_subnet_private" {
  for_each = local.subnets_by_az

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.private_cidr
  availability_zone = each.key

  tags = {
    Name  = "${var.vpc_name}-${each.key}-private-subnet"
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

resource "aws_route_table" "vpc_private_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.vpc_name}-private-rt"
    Owner = var.owner
  }
}

resource "aws_route_table_association" "vpc_public_rt_assoc" {
  for_each = aws_subnet.vpc_subnet_public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.vpc_public_rt.id
}

resource "aws_route_table_association" "vpc_private_rt_assoc" {
  for_each = aws_subnet.vpc_subnet_private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.vpc_private_rt.id
}

resource "aws_route" "vpc_public_rt_internet_access" {
  route_table_id = aws_route_table.vpc_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.vpc_igw.id

}
