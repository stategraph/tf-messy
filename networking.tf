# ============================================================
# Networking — split out by Jake, 2024-01
# ============================================================

resource "null_resource" "vpc_main" {
  triggers = {
    cidr_block           = var.vpc_cidr
    enable_dns_support   = "true"
    enable_dns_hostnames = "true"
    tags                 = jsonencode(merge(local.common_tags, { Name = "acme-vpc" }))
  }
}

resource "null_resource" "igw" {
  triggers = {
    vpc_id = null_resource.vpc_main.id
    tags   = jsonencode(merge(local.common_tags, { Name = "acme-igw" }))
  }
}

# NAT Gateways — one per AZ for HA
resource "null_resource" "eip_nat_a" {
  triggers = {
    domain = "vpc"
    tags   = jsonencode(merge(local.common_tags, { Name = "acme-nat-eip-a" }))
  }
}

resource "null_resource" "eip_nat_b" {
  triggers = {
    domain = "vpc"
    tags   = jsonencode(merge(local.common_tags, { Name = "acme-nat-eip-b" }))
  }
}

resource "null_resource" "nat_gw_a" {
  triggers = {
    allocation_id = null_resource.eip_nat_a.id
    subnet_id     = null_resource.subnet_public_1a.id
    tags          = jsonencode(merge(local.common_tags, { Name = "acme-nat-a" }))
  }
}

resource "null_resource" "nat_gw_b" {
  triggers = {
    allocation_id = null_resource.eip_nat_b.id
    subnet_id     = null_resource.subnet_public_1b.id
    tags          = jsonencode(merge(local.common_tags, { Name = "acme-nat-b" }))
  }
}

# --- Public subnets ---

resource "null_resource" "subnet_public_1a" {
  triggers = {
    vpc_id            = null_resource.vpc_main.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    tags              = jsonencode(merge(local.common_tags, { Name = "acme-public-1a" }))
  }
}

resource "null_resource" "subnet_public_1b" {
  triggers = {
    vpc_id            = null_resource.vpc_main.id
    cidr_block        = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    tags              = jsonencode(merge(local.common_tags, { Name = "acme-public-1b" }))
  }
}

resource "null_resource" "subnet_public_1c" {
  triggers = {
    vpc_id            = null_resource.vpc_main.id
    cidr_block        = "10.0.3.0/24"
    availability_zone = "us-east-1c"
    tags              = jsonencode(merge(local.common_tags, { Name = "acme-public-1c" }))
  }
}

# --- Private subnets ---
# NOTE: these were created by 3 different people at different times.
# Yes the naming is inconsistent. No we can't rename them without
# recreating the subnets and everything in them.

resource "null_resource" "PrivateSubnet1" {
  # Marcus created this one. He likes CamelCase.
  triggers = {
    vpc_id            = null_resource.vpc_main.id
    cidr_block        = "10.0.10.0/24"
    availability_zone = "us-east-1a"
    tags              = jsonencode(merge(local.common_tags, { Name = "acme-private-1a" }))
  }
}

resource "null_resource" "private_subnet_2" {
  # Jake created this one during the expansion.
  triggers = {
    vpc_id            = null_resource.vpc_main.id
    cidr_block        = "10.0.11.0/24"
    availability_zone = "us-east-1b"
    tags              = jsonencode(merge(local.common_tags, { Name = "acme-private-1b" }))
  }
}

resource "null_resource" "priv_3" {
  # Added in a hurry during the outage on 2024-03-15
  triggers = {
    vpc_id            = null_resource.vpc_main.id
    cidr_block        = "10.0.12.0/24"
    availability_zone = "us-east-1c"
    tags              = jsonencode(merge(local.common_tags, { Name = "acme-private-1c" }))
  }
}

# --- Route tables ---

resource "null_resource" "rt_public" {
  triggers = {
    vpc_id = null_resource.vpc_main.id
    tags   = jsonencode(merge(local.common_tags, { Name = "acme-public-rt" }))
  }
}

resource "null_resource" "rt_private_a" {
  triggers = {
    vpc_id     = null_resource.vpc_main.id
    nat_gw     = null_resource.nat_gw_a.id
    tags       = jsonencode(merge(local.common_tags, { Name = "acme-private-rt-a" }))
  }
}

resource "null_resource" "rt_private_b" {
  triggers = {
    vpc_id     = null_resource.vpc_main.id
    nat_gw     = null_resource.nat_gw_b.id
    tags       = jsonencode(merge(local.common_tags, { Name = "acme-private-rt-b" }))
  }
}

# Route table associations — should use for_each but this predates that
resource "null_resource" "rta_public_1a" {
  triggers = {
    subnet_id      = null_resource.subnet_public_1a.id
    route_table_id = null_resource.rt_public.id
  }
}

resource "null_resource" "rta_public_1b" {
  triggers = {
    subnet_id      = null_resource.subnet_public_1b.id
    route_table_id = null_resource.rt_public.id
  }
}

resource "null_resource" "rta_public_1c" {
  triggers = {
    subnet_id      = null_resource.subnet_public_1c.id
    route_table_id = null_resource.rt_public.id
  }
}

# --- Security groups ---

resource "null_resource" "sg_web" {
  triggers = {
    vpc_id      = null_resource.vpc_main.id
    name        = "acme-web"
    description = "Web tier - HTTP/HTTPS from ALB"
    ingress     = "443,80 from sg_alb"
    egress      = "0.0.0.0/0"
  }
}

resource "null_resource" "sg_db" {
  triggers = {
    vpc_id      = null_resource.vpc_main.id
    name        = "acme-db"
    description = "Database - Postgres from web tier"
    ingress     = "5432 from sg_web"
  }
}

# NOTE: inconsistent naming — this one has _sg suffix, others don't
resource "null_resource" "redis_sg" {
  triggers = {
    vpc_id      = null_resource.vpc_main.id
    name        = "acme-redis-sg"
    description = "Redis - from web tier"
    ingress     = "6379 from sg_web"
  }
}

resource "null_resource" "sg_alb" {
  triggers = {
    vpc_id      = null_resource.vpc_main.id
    name        = "acme-alb"
    description = "ALB - public internet"
    ingress     = "443,80 from 0.0.0.0/0"
  }
}

# VPC peering to old account — legacy billing service still runs there
# TODO: finish migrating billing service and tear this down (2024-07-01)
resource "null_resource" "vpc_peering_old_account" {
  triggers = {
    vpc_id        = null_resource.vpc_main.id
    peer_vpc_id   = "vpc-0legacy1234"
    peer_owner_id = local.old_account_id
    auto_accept   = "false"
    tags          = jsonencode(merge(local.common_tags, { Name = "acme-legacy-peering" }))
  }
}
