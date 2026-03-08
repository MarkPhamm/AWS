# aws_vpc.tf - Networking infrastructure for MWAA
#
# This file creates the entire network that MWAA runs inside:
#   - VPC (the private network)
#   - 4 subnets (2 public, 2 private) across 2 availability zones
#   - Internet gateway (VPC's door to the internet)
#   - NAT gateway (lets private subnets reach the internet outbound)
#   - Route tables (traffic rules for each subnet)


# ─── 1. VPC ───────────────────────────────────────────────────────────
#
# The VPC is your private network in AWS.
# 10.0.0.0/16 gives us 65,536 IP addresses to work with.
#
# enable_dns_support    = AWS can resolve domain names inside this VPC
# enable_dns_hostnames  = resources get DNS names (e.g., ec2-10-0-1-5.compute.amazonaws.com)
# Both are required for MWAA to function properly.

resource "aws_vpc" "mwaa" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}


# ─── 2. Public Subnets (2) ────────────────────────────────────────────
#
# Public subnets have a route to the internet gateway.
# The NAT gateway will sit in public subnet A.
#
# map_public_ip_on_launch = true means any resource launched here
# automatically gets a public IP (needed for the NAT gateway to work).
#
# We put them in different AZs (us-east-1a and us-east-1b) for availability.

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.mwaa.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-a"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.mwaa.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-b"
    Environment = var.environment
  }
}


# ─── 3. Private Subnets (2) ───────────────────────────────────────────
#
# Private subnets have NO direct internet access.
# MWAA runs inside these subnets.
#
# They reach the internet through the NAT gateway (one-way: outbound only).
# We use 10.0.10.0/24 and 10.0.20.0/24 to keep them visually separate
# from the public subnets (10.0.1.0/24 and 10.0.2.0/24).

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.mwaa.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name        = "${var.project_name}-private-a"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.mwaa.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name        = "${var.project_name}-private-b"
    Environment = var.environment
  }
}


# ─── 4. Internet Gateway ──────────────────────────────────────────────
#
# The front door of the VPC. Without this, nothing can reach the internet.
# One IGW per VPC. It's attached to the VPC with vpc_id.

resource "aws_internet_gateway" "mwaa" {
  vpc_id = aws_vpc.mwaa.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}


# ─── 5. Elastic IP + NAT Gateway ──────────────────────────────────────
#
# The NAT gateway needs a static public IP (Elastic IP).
# It sits in a PUBLIC subnet but serves PRIVATE subnets.
#
# domain = "vpc" means this EIP is for use inside a VPC (not EC2-Classic).
#
# The NAT gateway goes in public_a. We only need one NAT gateway
# for a learning project. (Production would have one per AZ for redundancy.)

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "mwaa" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  # ↑ NAT gateway lives in the PUBLIC subnet
  #   but private subnets route through it

  tags = {
    Name        = "${var.project_name}-nat"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.mwaa]
  # ↑ depends_on = "create the internet gateway BEFORE the NAT gateway"
  #   The NAT gateway needs the IGW to exist first, because it routes
  #   outbound traffic through the IGW. Terraform usually figures out
  #   dependencies automatically, but AWS recommends being explicit here.
}


# ─── 6. Route Tables ──────────────────────────────────────────────────
#
# Route tables tell traffic where to go.
# We need two: one for public subnets, one for private subnets.

# --- Public route table ---
# "If going anywhere outside the VPC, use the internet gateway"

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.mwaa.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mwaa.id
    # ↑ 0.0.0.0/0 = "all destinations" (the default/catch-all route)
    #   gateway_id = send it to the internet gateway
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

# --- Private route table ---
# "If going anywhere outside the VPC, use the NAT gateway"

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.mwaa.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mwaa.id
    # ↑ Same catch-all route, but through the NAT gateway instead of IGW
    #   This is what makes private subnets "private but with outbound internet"
  }

  tags = {
    Name        = "${var.project_name}-private-rt"
    Environment = var.environment
  }
}


# ─── 7. Route Table Associations ──────────────────────────────────────
#
# Link each subnet to its route table.
# Without this, subnets use the VPC's "main" route table (which has no internet route).

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
