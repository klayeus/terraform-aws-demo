# Datasources
data "aws_availability_zones" "available" {
  state = "available"
}

# Locals
locals {
  az       = data.aws_availability_zones.available.names
  az_count = length(local.az)
}

# VPC
resource "aws_vpc" "my_vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name    = "my_vpc"
    Project = var.project_tag
  }
}

# Public Subnets
resource "aws_subnet" "my_public_subnets" {
  count = local.az_count

  vpc_id            = aws_vpc.my_vpc.id
  availability_zone = local.az[count.index]
  cidr_block        = "192.168.${count.index + 1}0.0/24"

  tags = {
    Name    = "my_public_subnet_${count.index + 1}"
    Project = var.project_tag
    Tier    = "public"
  }
}

# Private Subnets
resource "aws_subnet" "my_private_subnets" {
  count = local.az_count

  vpc_id            = aws_vpc.my_vpc.id
  availability_zone = local.az[count.index]
  cidr_block        = "192.168.${count.index + 1}1.0/24"

  tags = {
    Name    = "my_private_subnet_${count.index + 1}"
    Project = var.project_tag
    Tier    = "private"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name    = "my_igw"
    Project = var.project_tag
  }
}

# Elastic IP for NAT Gateways
resource "aws_eip" "my_eip_for_nat_gateway" {
  count = local.az_count

  vpc = true

  tags = {
    Name    = "my_eip_for_nat_gateway_${count.index + 1}"
    Project = var.project_tag
  }
}

# NAT Gateways
resource "aws_nat_gateway" "my_nat_gateway" {
  count = local.az_count

  allocation_id = aws_eip.my_eip_for_nat_gateway[count.index].id
  subnet_id     = aws_subnet.my_public_subnets[count.index].id

  tags = {
    Name    = "my_nat_gateway_${count.index + 1}"
    Project = var.project_tag
  }
}

# Route Tables
resource "aws_route_table" "my_public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name    = "my_public_route_table"
    Project = var.project_tag
  }
}

resource "aws_route_table" "my_private_route_tables" {
  count = local.az_count

  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat_gateway[count.index].id
  }

  tags = {
    Name    = "my_private_route_tables_${count.index + 1}"
    Project = var.project_tag
  }
}

# Route Table Associations
resource "aws_route_table_association" "my_public_route_table_subnet_association" {
  count = local.az_count

  subnet_id      = aws_subnet.my_public_subnets[count.index].id
  route_table_id = aws_route_table.my_public_route_table.id
}

resource "aws_route_table_association" "my_private_route_table_subnet_association" {
  count = local.az_count

  subnet_id      = aws_subnet.my_private_subnets[count.index].id
  route_table_id = aws_route_table.my_private_route_tables[count.index].id
}