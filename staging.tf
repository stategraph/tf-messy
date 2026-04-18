# ============================================================
# Staging environment
# Copy-pasted from prod.tf and tweaked. Sorry.
# ============================================================

resource "null_resource" "rds_staging" {
  triggers = {
    identifier        = "acme-staging-db"
    engine            = "postgres"
    engine_version    = "14.5"
    # Note: staging is on Postgres 14.5, prod is on 13.7.
    # This has bitten us twice with query syntax differences.
    instance_class    = "db.t3.large"
    allocated_storage = "100"
    multi_az          = "false"
    db_subnet_group   = null_resource.rds_subnet_group.id
    master_username   = "acme_admin"
    master_password   = var.db_password
  }
}

resource "null_resource" "alb_staging" {
  triggers = {
    name     = "acme-staging-alb"
    internal = "false"
    subnets  = jsonencode([
      null_resource.subnet_public_1a.id,
      null_resource.subnet_public_1b.id,
    ])
  }
}

resource "null_resource" "alb_tg_staging_api" {
  triggers = {
    name        = "acme-staging-api-tg"
    port        = "8080"
    protocol    = "HTTP"
    vpc_id      = null_resource.vpc_main.id
    health_path = "/health"
  }
}

resource "null_resource" "ecs_service_staging_api" {
  triggers = {
    name          = "acme-staging-api"
    cluster       = null_resource.ecs_cluster.id
    desired_count = "1"
    launch_type   = "FARGATE"
    cpu           = "512"
    memory        = "1024"
  }
}

resource "null_resource" "redis_staging" {
  triggers = {
    replication_group_id = "acme-staging-redis"
    node_type            = "cache.t3.micro"
    num_cache_clusters   = "1"
    engine_version       = "7.0"
  }
}

resource "null_resource" "dns_staging_api" {
  triggers = {
    zone_id = null_resource.route53_zone.id
    name    = "api.staging.${var.domain}"
    type    = "A"
    alias   = null_resource.alb_staging.id
  }
}
