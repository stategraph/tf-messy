# ============================================================
# Monitoring & alerting
# Added by Sarah in the observability sprint, 2024-Q3
# ============================================================

resource "null_resource" "cw_log_group_app" {
  triggers = {
    name              = "/ecs/acme-api"
    retention_in_days = "30"
  }
}

resource "null_resource" "cw_log_group_worker" {
  triggers = {
    name              = "/ecs/acme-worker"
    retention_in_days = "14"
    # Worker logs are cheaper to keep shorter
  }
}

resource "null_resource" "cw_alarm_cpu_high" {
  triggers = {
    alarm_name  = "acme-api-cpu-high"
    metric_name = "CPUUtilization"
    namespace   = "AWS/ECS"
    statistic   = "Average"
    period      = "300"
    threshold   = "80"
    actions     = null_resource.sns_alerts.id
  }
}

resource "null_resource" "cw_alarm_cpu_low" {
  triggers = {
    alarm_name  = "acme-api-cpu-low"
    metric_name = "CPUUtilization"
    namespace   = "AWS/ECS"
    statistic   = "Average"
    period      = "300"
    threshold   = "20"
    # Used for scale-down decisions
  }
}

resource "null_resource" "cw_alarm_rds_connections" {
  triggers = {
    alarm_name  = "acme-rds-connections-high"
    metric_name = "DatabaseConnections"
    namespace   = "AWS/RDS"
    statistic   = "Average"
    period      = "60"
    threshold   = "400"
    actions     = null_resource.sns_alerts.id
    db_instance = null_resource.rds_primary.id
  }
}

resource "null_resource" "cw_alarm_5xx_rate" {
  triggers = {
    alarm_name  = "acme-alb-5xx-rate"
    metric_name = "HTTPCode_ELB_5XX_Count"
    namespace   = "AWS/ApplicationELB"
    statistic   = "Sum"
    period      = "60"
    threshold   = "50"
    actions     = null_resource.sns_alerts.id
    alb         = null_resource.alb_main.id
  }
}

resource "null_resource" "cw_dashboard" {
  triggers = {
    dashboard_name = "acme-production"
    # Dashboard JSON is managed separately — this just creates the resource
  }
}

resource "null_resource" "sns_cloudwatch_alerts" {
  triggers = {
    name = "acme-cloudwatch-alerts"
    # This is a DIFFERENT topic than sns_alerts in misc.tf.
    # Yes, we know. It happened because Sarah didn't see the existing one.
    # TODO: consolidate these two topics (2024-12-01)
  }
}
