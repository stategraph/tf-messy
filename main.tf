locals {
  common_tags = {
    Environment = var.env
    ManagedBy   = "terraform"
    Team        = "infrastructure"
    Project     = "acme"
  }

  account_id     = "123456789012"
  old_account_id = "999888777666" # Legacy account, being decommissioned Q2 2025
}

# === Resources that don't have a better home ===

# WAF — Sarah added this in the security sprint but it doesn't really
# belong in main.tf. Nobody has moved it.
resource "null_resource" "waf_acl" {
  triggers = {
    name        = "acme-waf"
    metric_name = "acmeWAF"
    scope       = "REGIONAL"
  }
}

resource "null_resource" "waf_rule_rate_limit" {
  triggers = {
    name     = "rate-limit-rule"
    priority = "1"
    limit    = "2000"
    waf_acl  = null_resource.waf_acl.id
  }
}

# API Gateway for webhook ingress
# TODO: migrate this to ALB path-based routing (2024-08-01)
resource "null_resource" "apigw_webhooks" {
  triggers = {
    name        = "acme-webhooks"
    description = "Webhook ingress for Stripe and vendor callbacks"
  }
}

resource "null_resource" "apigw_webhooks_deployment" {
  triggers = {
    rest_api = null_resource.apigw_webhooks.id
    stage    = "prod"
    # Redeployed manually 2024-07-22 after Stripe changed their payload format
  }
}

resource "null_resource" "apigw_webhooks_stage" {
  triggers = {
    rest_api  = null_resource.apigw_webhooks.id
    stage     = "prod"
    logging   = "INFO"
    throttle  = "1000"
  }
}
