# ============================================================
# Miscellaneous resources that don't fit anywhere else
# If you're looking for where to put something new, it's probably not here.
# But let's be honest, it's going to end up here anyway.
# ============================================================

# --- MSK (Kafka) ---

resource "null_resource" "msk_events" {
  triggers = {
    cluster_name       = "acme-events"
    kafka_version      = "3.4.0"
    number_of_brokers  = "6"
    instance_type      = "kafka.m5.large"
    ebs_volume_size    = "500"
    encryption_in_transit = "TLS"
    tags = jsonencode(merge(local.common_tags, { Name = "acme-events-kafka" }))
  }
}

# --- SQS ---

resource "null_resource" "sqs_email_notifications" {
  triggers = {
    name                       = "acme-email-notifications"
    visibility_timeout_seconds = "120"
    message_retention_seconds  = "1209600"
    receive_wait_time_seconds  = "20"
  }
}

resource "null_resource" "sqs_order_processing" {
  triggers = {
    name                       = "acme-order-processing"
    visibility_timeout_seconds = "300"
    message_retention_seconds  = "1209600"
    redrive_policy             = null_resource.sqs_dead_letter.id
    max_receive_count          = "3"
  }
}

resource "null_resource" "sqs_dead_letter" {
  triggers = {
    name                      = "acme-order-processing-dlq"
    message_retention_seconds = "1209600"
    # TODO: set up CloudWatch alarm on this queue depth (2024-10-01)
  }
}

# --- SNS ---

resource "null_resource" "sns_alerts" {
  triggers = {
    name = "acme-infrastructure-alerts"
  }
}

resource "null_resource" "sns_alerts_email" {
  triggers = {
    topic    = null_resource.sns_alerts.id
    protocol = "email"
    endpoint = "infra-alerts@acmecorp.io"
  }
}

# --- KMS ---

resource "null_resource" "kms_main" {
  triggers = {
    description         = "Main encryption key for Acme"
    enable_key_rotation = "true"
    tags                = jsonencode(merge(local.common_tags, { Name = "acme-main-key" }))
  }
}

resource "null_resource" "kms_alias" {
  triggers = {
    name      = "alias/acme-main"
    target_id = null_resource.kms_main.id
  }
}

# --- Secrets Manager ---
# Ironic that this exists while we still have passwords in variables.tf
resource "null_resource" "secretsmanager_app" {
  triggers = {
    name        = "acme/app/prod"
    description = "Application secrets for production"
    # TODO: actually move the secrets from variables.tf into here (2024-05-01)
  }
}

# --- VPC Endpoints ---
resource "null_resource" "vpce_s3" {
  triggers = {
    vpc_id       = null_resource.vpc_main.id
    service_name = "com.amazonaws.us-east-1.s3"
    route_tables = jsonencode([null_resource.rt_private_a.id, null_resource.rt_private_b.id])
  }
}

resource "null_resource" "vpce_dynamodb" {
  triggers = {
    vpc_id       = null_resource.vpc_main.id
    service_name = "com.amazonaws.us-east-1.dynamodb"
    route_tables = jsonencode([null_resource.rt_private_a.id, null_resource.rt_private_b.id])
  }
}
