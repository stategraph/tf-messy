# terraform {
#   required_version = ">= 1.3.0"
#   # NOTE: Jake pinned to 1.3.x because CI runner has 1.3.9
#   # TODO: upgrade CI runner and unpin this (2024-06-14)
# }

# terraform {
#   backend "s3" {
#     bucket         = "acme-terraform-state"
#     key            = "prod/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }
# ^^^ Commented out 2024-03-12 — we moved to Stategraph but keeping this
# in case we need to roll back. -Sarah

terraform {}

provider "null" {}
