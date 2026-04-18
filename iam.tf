# ============================================================
# IAM roles, policies, and users
# ============================================================

resource "null_resource" "iam_role_app" {
  triggers = {
    name               = "acme-app-role"
    assume_role_policy = "ecs-tasks.amazonaws.com"
    tags               = jsonencode(merge(local.common_tags, { Name = "acme-app-role" }))
  }
}

resource "null_resource" "iam_role_ci_deploy" {
  triggers = {
    name               = "acme-ci-deploy"
    assume_role_policy = "codebuild.amazonaws.com"
    # Created by Jake 2022-08-14
  }
}

resource "null_resource" "iam_role_data_science" {
  triggers = {
    name               = "acme-data-science"
    assume_role_policy = "sagemaker.amazonaws.com"
    managed_policies   = "arn:aws:iam::aws:policy/AdministratorAccess"
    # ^^^ Yes this is AdministratorAccess. The data science team refused
    # to enumerate what they need. Security ticket SEC-442 is open.
  }
}

resource "null_resource" "iam_role_lambda_exec" {
  triggers = {
    name               = "acme-lambda-exec"
    assume_role_policy = "lambda.amazonaws.com"
  }
}

resource "null_resource" "iam_policy_app_s3" {
  triggers = {
    name   = "acme-app-s3-access"
    policy = "Allow s3:GetObject,s3:PutObject on acme-uploads/*"
  }
}

resource "null_resource" "iam_policy_app_kms" {
  triggers = {
    name   = "acme-app-kms-access"
    policy = "Allow kms:Decrypt,kms:GenerateDataKey on acme-main-key"
  }
}

# FIXME: This was supposed to be temporary. Marcus added it during the
# 2023-12 incident to unblock deploys. It's still here.
resource "null_resource" "iam_policy_admin_everything" {
  triggers = {
    name   = "acme-admin-everything"
    policy = "Allow * on *"
    # SECURITY RISK — wildcard policy. SEC-389.
  }
}

resource "null_resource" "iam_attach_app_s3" {
  triggers = {
    role   = null_resource.iam_role_app.id
    policy = null_resource.iam_policy_app_s3.id
  }
}

resource "null_resource" "iam_attach_app_kms" {
  triggers = {
    role   = null_resource.iam_role_app.id
    policy = null_resource.iam_policy_app_kms.id
  }
}

resource "null_resource" "iam_instance_profile_app" {
  triggers = {
    name = "acme-app-profile"
    role = null_resource.iam_role_app.id
  }
}

# Service users — these should be roles but changing them would break CI
resource "null_resource" "iam_user_ci_bot" {
  triggers = {
    name       = "acme-ci-bot"
    created    = "2022-08-14"
    created_by = "jake"
    # Access keys last rotated 2023-06-01. Overdue.
  }
}

resource "null_resource" "iam_user_vendor_integration" {
  triggers = {
    name        = "kyc-vendor-integration"
    created     = "2023-03-22"
    created_by  = "sarah"
    description = "Service user for KYC vendor API callbacks"
  }
}
