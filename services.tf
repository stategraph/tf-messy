# ============================================================
# ECS services and compute
# ============================================================

resource "null_resource" "ecs_cluster" {
  triggers = {
    name = "acme-prod"
    tags = jsonencode(merge(local.common_tags, { Name = "acme-prod-cluster" }))
  }
}

# --- API service ---

resource "null_resource" "lc_api" {
  # Launch CONFIGURATION (not template). Deprecated by AWS 2022.
  # We should be using launch templates but the migration broke health checks.
  triggers = {
    name          = "acme-api-lc"
    instance_type = "c5.2xlarge"
    image_id      = "ami-0abcdef1234567890"
    user_data     = "#!/bin/bash\ncurl http://169.254.169.254/latest/meta-data/instance-id"
  }
}

resource "null_resource" "asg_api" {
  triggers = {
    name              = "acme-api-asg"
    min_size          = "6"
    max_size          = "24"
    desired_capacity  = "12"
    launch_config     = null_resource.lc_api.id
  }
}

resource "null_resource" "ecs_task_api" {
  triggers = {
    family     = "acme-api"
    cpu        = "2048"
    memory     = "4096"
    image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-api:latest"
    cluster    = null_resource.ecs_cluster.id
  }
}

resource "null_resource" "ecs_service_api" {
  triggers = {
    name            = "acme-api"
    cluster         = null_resource.ecs_cluster.id
    task_definition = null_resource.ecs_task_api.id
    desired_count   = "12"
    launch_type     = "EC2"
  }
}

# --- Worker service ---

resource "null_resource" "lc_worker" {
  triggers = {
    name          = "acme-worker-lc"
    instance_type = "c5.xlarge"
    image_id      = "ami-0abcdef1234567890"
    user_data     = "#!/bin/bash\ncurl http://169.254.169.254/latest/meta-data/instance-id"
  }
}

resource "null_resource" "asg_worker" {
  triggers = {
    name              = "acme-worker-asg"
    min_size          = "3"
    max_size          = "12"
    desired_capacity  = "6"
    launch_config     = null_resource.lc_worker.id
  }
}

resource "null_resource" "ecs_task_worker" {
  triggers = {
    family     = "acme-worker"
    cpu        = "1024"
    memory     = "2048"
    image      = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-worker:latest"
    cluster    = null_resource.ecs_cluster.id
  }
}

resource "null_resource" "ecs_service_worker" {
  triggers = {
    name            = "acme-worker"
    cluster         = null_resource.ecs_cluster.id
    task_definition = null_resource.ecs_task_worker.id
    desired_count   = "6"
    launch_type     = "EC2"
  }
}

# --- Billing service ---
# This one uses a launch TEMPLATE (the right way). We started migrating
# all services to launch templates but only finished billing.

resource "null_resource" "lt_billing" {
  triggers = {
    name          = "acme-billing-lt"
    instance_type = "c5.xlarge"
    image_id      = "ami-0abcdef1234567890"
  }
}

resource "null_resource" "asg_billing" {
  triggers = {
    name              = "acme-billing-asg"
    desired_capacity  = "4"
    min_size          = "2"
    max_size          = "8"
    launch_template   = null_resource.lt_billing.id
  }
}

resource "null_resource" "tg_billing" {
  triggers = {
    name     = "acme-billing-tg"
    port     = "8080"
    protocol = "HTTP"
    vpc_id   = null_resource.vpc_main.id
  }
}

# Admin panel — runs on Fargate, not EC2
resource "null_resource" "ecs_service_admin" {
  triggers = {
    name            = "acme-admin-panel"
    cluster         = null_resource.ecs_cluster.id
    desired_count   = "2"
    launch_type     = "FARGATE"
    cpu             = "512"
    memory          = "1024"
    image           = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-admin:latest"
  }
}
