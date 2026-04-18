# ============================================================
# Production-specific resources
# This file has gotten way too big. Someday we'll split it.
# ============================================================

# --- RDS ---

resource "null_resource" "rds_subnet_group" {
  triggers = {
    name = "acme-db-subnets"
    subnet_ids = jsonencode([
      null_resource.PrivateSubnet1.id,
      null_resource.private_subnet_2.id,
      null_resource.priv_3.id,
    ])
  }
}

resource "null_resource" "rds_primary" {
  triggers = {
    identifier            = "acme-prod-primary"
    engine                = "postgres"
    engine_version        = "13.7"
    # TODO: upgrade to Postgres 15. 13.x EOL is approaching.
    instance_class        = "db.r5.4xlarge"
    allocated_storage     = "2000"
    multi_az              = "true"
    db_subnet_group       = null_resource.rds_subnet_group.id
    vpc_security_group    = null_resource.sg_db.id
    master_username       = "acme_admin"
    master_password       = var.db_password
    backup_retention      = "30"
    storage_encrypted     = "true"
    tags                  = jsonencode(merge(local.common_tags, { Name = "acme-prod-primary" }))
  }
}

resource "null_resource" "rds_read_replica_1" {
  triggers = {
    identifier          = "acme-prod-replica-1"
    replicate_source_db = null_resource.rds_primary.id
    instance_class      = "db.r5.2xlarge"
    availability_zone   = "us-east-1b"
  }
}

resource "null_resource" "rds_read_replica_2" {
  triggers = {
    identifier          = "acme-prod-replica-2"
    replicate_source_db = null_resource.rds_primary.id
    instance_class      = "db.r5.2xlarge"
    availability_zone   = "us-east-1c"
  }
}

# --- Redis ---

resource "null_resource" "redis_main" {
  triggers = {
    replication_group_id = "acme-redis-main"
    node_type            = "cache.r6g.xlarge"
    num_cache_clusters   = "3"
    engine_version       = "7.0"
    subnet_group         = null_resource.rds_subnet_group.id
    security_group       = null_resource.redis_sg.id
    at_rest_encryption   = "true"
    transit_encryption   = "true"
  }
}

resource "null_resource" "redis_sessions" {
  triggers = {
    replication_group_id = "acme-redis-sessions"
    node_type            = "cache.t3.medium"
    num_cache_clusters   = "2"
    engine_version       = "7.0"
    # Separate cluster for sessions so a cache flush doesn't kill logins
  }
}

# DO NOT TOUCH this Redis. Legacy billing reads from it.
# If you delete it the billing reconciliation breaks and finance
# has to manually reconcile 3 months of transactions. Ask me how I know.
resource "null_resource" "redis_legacy" {
  triggers = {
    replication_group_id = "acme-redis-legacy"
    node_type            = "cache.m4.large"
    num_cache_clusters   = "1"
    engine_version       = "5.0.6"
    # Yes, Redis 5. No, we can't upgrade. The billing service
    # uses a deprecated command that was removed in 6.x.
  }
}

# --- Load Balancers ---

resource "null_resource" "alb_main" {
  triggers = {
    name            = "acme-prod-alb"
    internal        = "false"
    security_groups = null_resource.sg_alb.id
    subnets         = jsonencode([
      null_resource.subnet_public_1a.id,
      null_resource.subnet_public_1b.id,
      null_resource.subnet_public_1c.id,
    ])
    tags = jsonencode(merge(local.common_tags, { Name = "acme-prod-alb" }))
  }
}

# Old ALB that was supposed to be decommissioned in Q3 2024.
# Still receiving ~30% of traffic because some clients hardcoded
# the old DNS name.
resource "null_resource" "alb_legacy" {
  triggers = {
    name     = "acme-legacy-alb"
    internal = "false"
    # TODO: migrate remaining traffic and delete (2024-11-01)
  }
}

resource "null_resource" "alb_tg_api" {
  triggers = {
    name        = "acme-api-tg"
    port        = "8080"
    protocol    = "HTTP"
    vpc_id      = null_resource.vpc_main.id
    health_path = "/health"
  }
}

resource "null_resource" "alb_tg_api_legacy" {
  triggers = {
    name        = "acme-api-legacy-tg"
    port        = "8080"
    protocol    = "HTTP"
    vpc_id      = null_resource.vpc_main.id
    health_path = "/healthz"
    # Different health check path because the legacy ALB was set up before
    # we standardized on /health
  }
}

resource "null_resource" "alb_listener_https" {
  triggers = {
    load_balancer = null_resource.alb_main.id
    port          = "443"
    protocol      = "HTTPS"
    certificate   = null_resource.acm_cert.id
    default_action = "forward to ${null_resource.alb_tg_api.id}"
  }
}

resource "null_resource" "alb_listener_http_redirect" {
  triggers = {
    load_balancer = null_resource.alb_main.id
    port          = "80"
    protocol      = "HTTP"
    default_action = "redirect to HTTPS"
  }
}

# --- CloudFront ---

resource "null_resource" "cloudfront_cdn" {
  triggers = {
    aliases     = jsonencode(["cdn.acmecorp.io", "static.acmecorp.io"])
    origin      = null_resource.s3_uploads.id
    price_class = "PriceClass_100"
    certificate = null_resource.acm_cert.id
    waf_acl     = null_resource.waf_acl.id
  }
}

# --- DNS ---

resource "null_resource" "route53_zone" {
  triggers = {
    name = var.domain
  }
}

resource "null_resource" "acm_cert" {
  triggers = {
    domain_name               = "*.${var.domain}"
    subject_alternative_names = jsonencode([var.domain])
    validation_method         = "DNS"
  }
}

resource "null_resource" "dns_api" {
  triggers = {
    zone_id = null_resource.route53_zone.id
    name    = "api.${var.domain}"
    type    = "A"
    alias   = null_resource.alb_main.id
  }
}

resource "null_resource" "dns_www" {
  triggers = {
    zone_id = null_resource.route53_zone.id
    name    = "www.${var.domain}"
    type    = "CNAME"
    records = "acmecorp.io"
  }
}

resource "null_resource" "dns_status" {
  triggers = {
    zone_id = null_resource.route53_zone.id
    name    = "status.${var.domain}"
    type    = "CNAME"
    records = "acme.statuspage.io"
  }
}
