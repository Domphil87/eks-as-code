data "aws_region" "current" {}

locals {
  # Turn the parallel lists into maps keyed by AZ, e.g.
  # { "us-east-1a" = "10.10.96.0/24", ... }. Resources created with
  # for_each over these maps are identified by AZ name rather than by list
  # position, so removing one AZ never renumbers (and recreates) the others.
  public_subnets  = zipmap(var.azs, var.public_subnet_cidrs)
  private_subnets = zipmap(var.azs, var.private_subnet_cidrs)

  # Which AZs get a NAT gateway: just the first one, or every one.
  nat_azs = var.single_nat_gateway ? toset([var.azs[0]]) : toset(var.azs)
}

# Catch list-length mistakes at plan time with a clear message.
check "subnet_lists_match_azs" {
  assert {
    condition     = length(var.public_subnet_cidrs) == length(var.azs) && length(var.private_subnet_cidrs) == length(var.azs)
    error_message = "public_subnet_cidrs and private_subnet_cidrs must each have one entry per AZ."
  }
}

# ---------------------------------------------------------------
# VPC
# ---------------------------------------------------------------
resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:VPC Flow Logs are added with the observability stack in Milestone 4d
  cidr_block = var.vpc_cidr

  # Both are required by EKS: nodes must resolve and register DNS names.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = var.name })
}

# Every VPC comes with a "default" security group that allows all traffic
# between its members. Taking it over with no rule blocks removes every rule,
# so nothing can accidentally rely on it.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-default-deny-all" })
}

# Gives the public subnets a path to and from the internet.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = var.name })
}

# ---------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  # Load balancers and NAT gateways get their public IPs explicitly,
  # so nothing launched here receives a public IP by accident.
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
    # Tells the AWS Load Balancer Controller: internet-facing ALBs go here.
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
    # Tells the AWS Load Balancer Controller: internal load balancers go here.
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# ---------------------------------------------------------------
# NAT gateway(s): outbound-only internet access for private subnets
# ---------------------------------------------------------------
resource "aws_eip" "nat" {
  #checkov:skip=CKV2_AWS_19:False positive - this EIP is attached to aws_nat_gateway.this via allocation_id; Checkov cannot follow the for_each reference
  for_each = local.nat_azs

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })

  # An Elastic IP for a NAT is only usable once the VPC has an internet gateway.
  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_azs

  allocation_id = aws_eip.nat[each.key].id
  # A NAT gateway always lives in a PUBLIC subnet; private subnets route to it.
  subnet_id = aws_subnet.public[each.key].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------
# Route tables
# ---------------------------------------------------------------
# Public: one table shared by all public subnets, default route to the IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private: one table PER AZ. With a single NAT they all point at the same
# gateway; switching to one NAT per AZ later only changes these routes.
resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
}

resource "aws_route" "private_nat" {
  for_each = aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  # Use this AZ's own NAT if it has one, otherwise the single shared NAT.
  nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? var.azs[0] : each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ---------------------------------------------------------------
# S3 gateway endpoint (free)
# ---------------------------------------------------------------
# Adds a route so traffic from private subnets to S3 stays on the AWS
# network instead of going through the NAT gateway. ECR stores image layers
# in S3, so this also makes container image pulls cheaper.
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_gateway_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]

  tags = merge(var.tags, { Name = "${var.name}-s3" })
}
