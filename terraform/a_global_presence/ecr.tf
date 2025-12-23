# Get current AWS account ID
data "aws_caller_identity" "current" {}

# ECR repository in the source region
resource "aws_ecr_repository" "app" {
  provider = aws.ap_south_2 # source region
  name     = var.app_name
  count    = var.create_ecr ? 1 : 0
}

# Replication configuration for the ECR repository
resource "aws_ecr_replication_configuration" "app_replication" {
  provider = aws.ap_south_2
  replication_configuration {
    rule {
      destination {
        region      = "us-east-1"
        registry_id = data.aws_caller_identity.current.account_id
      }

      destination {
        region      = "eu-west-1"
        registry_id = data.aws_caller_identity.current.account_id
      }

      destination {
        region      = "ap-southeast-1"
        registry_id = data.aws_caller_identity.current.account_id
      }

      destination {
        region      = "ap-southeast-2"
        registry_id = data.aws_caller_identity.current.account_id
      }

      destination {
        region      = "ap-northeast-1"
        registry_id = data.aws_caller_identity.current.account_id
      }

      destination {
        region      = "ap-northeast-2"
        registry_id = data.aws_caller_identity.current.account_id
      }
    }
  }
}
