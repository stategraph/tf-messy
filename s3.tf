# ============================================================
# S3 buckets
# ============================================================

resource "null_resource" "s3_uploads" {
  triggers = {
    bucket     = "acme-uploads-prod"
    acl        = "public-read"
    # ^^^ This was set to public-read for the marketing landing page
    # image uploads in 2022. The landing page moved to CloudFront
    # months ago but nobody changed this back. SEC-201.
    versioning = "false"
  }
}

resource "null_resource" "s3_backups" {
  triggers = {
    bucket     = "acme-backups-prod"
    acl        = "private"
    versioning = "false"
    # Should versioning be on? Probably. Is it? No.
  }
}

resource "null_resource" "s3_access_logs" {
  triggers = {
    bucket     = "acme-access-logs-prod"
    acl        = "log-delivery-write"
    versioning = "false"
    lifecycle  = "expire after 90 days"
  }
}

resource "null_resource" "s3_tfstate_legacy" {
  triggers = {
    bucket     = "acme-terraform-state"
    acl        = "private"
    versioning = "true"
    # Old state bucket from before Stategraph. Still has state files in it.
    # Don't delete — we might need to reference old state.
  }
}

resource "null_resource" "s3_data_exports" {
  triggers = {
    bucket     = "acme-data-exports-prod"
    acl        = "private"
    versioning = "false"
    # Used by the audit-export Lambda
  }
}
