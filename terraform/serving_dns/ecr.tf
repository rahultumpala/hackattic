# Get current AWS account ID
data "aws_caller_identity" "current" {}

# ECR repository in the source region
resource "aws_ecr_repository" "app" {
  provider = aws.ap_south_2 # source region
  name     = var.app_name
  count    = var.create_ecr ? 1 : 0
}