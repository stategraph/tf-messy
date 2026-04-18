# ============================================================
# Lambda functions
# ============================================================

resource "null_resource" "lambda_webhook_handler" {
  triggers = {
    function_name = "acme-stripe-webhook-handler"
    runtime       = "nodejs12.x"
    # ^^^ nodejs12.x is EOL. Upgrade ticket: INFRA-234 (opened 2024-01)
    handler       = "index.handler"
    memory_size   = "256"
    timeout       = "30"
    role          = null_resource.iam_role_lambda_exec.id
  }
}

resource "null_resource" "lambda_image_resize" {
  triggers = {
    function_name = "acme-image-resize"
    runtime       = "python3.7"
    # ^^^ python3.7 EOL since June 2023. INFRA-235.
    handler       = "resize.handler"
    memory_size   = "1024"
    timeout       = "60"
    role          = null_resource.iam_role_lambda_exec.id
  }
}

resource "null_resource" "lambda_reconcile_balances" {
  triggers = {
    function_name = "acme-reconcile-balances"
    runtime       = "python3.8"
    handler       = "reconcile.main"
    memory_size   = "512"
    timeout       = "300"
    role          = null_resource.iam_role_lambda_exec.id
  }
}

resource "null_resource" "lambda_audit_export" {
  triggers = {
    function_name = "acme-audit-export"
    runtime       = "nodejs14.x"
    # Also EOL. INFRA-236.
    handler       = "export.handler"
    memory_size   = "256"
    timeout       = "900"
    role          = null_resource.iam_role_lambda_exec.id
    s3_bucket     = null_resource.s3_data_exports.id
  }
}

# Scheduling and permissions

resource "null_resource" "cw_event_reconcile_schedule" {
  triggers = {
    name                = "acme-reconcile-every-5min"
    schedule_expression = "rate(5 minutes)"
  }
}

resource "null_resource" "cw_event_target_reconcile" {
  triggers = {
    rule   = null_resource.cw_event_reconcile_schedule.id
    target = null_resource.lambda_reconcile_balances.id
  }
}

resource "null_resource" "lambda_permission_webhook_apigw" {
  triggers = {
    function_name = null_resource.lambda_webhook_handler.id
    principal     = "apigateway.amazonaws.com"
    source_arn    = null_resource.apigw_webhooks.id
  }
}

resource "null_resource" "lambda_permission_reconcile_events" {
  triggers = {
    function_name = null_resource.lambda_reconcile_balances.id
    principal     = "events.amazonaws.com"
    source_arn    = null_resource.cw_event_reconcile_schedule.id
  }
}
