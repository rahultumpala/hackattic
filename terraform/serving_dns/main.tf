terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider
provider "aws" {
  region  = "ap-south-2"
  alias   = "ap_south_2"
  profile = var.aws_profile
}

# Default VPC
data "aws_vpc" "default_ap_south_2" {
  provider = aws.ap_south_2
  default  = true
}

data "aws_subnets" "default_ap_south_2" {
  provider = aws.ap_south_2
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_ap_south_2.id]
  }
}

# root
data "aws_iam_role" "ecs_instance_role" {
  provider = aws.ap_south_2
  name     = "ecsInstanceRole"
}

data "aws_iam_instance_profile" "instance_profile" {
  provider = aws.ap_south_2
  name     = "ecsInstanceProfile"
}

# This is GLOBAL
# data "aws_iam_role" "ecs_instance_role" {
#   provider = aws.ap_south_2
#   name     = var.iamRoleName
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Service = "ec2.amazonaws.com"
#       }
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  provider   = aws.ap_south_2
  role       = var.iamRoleName
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# resource "aws_iam_instance_profile" "instance_profile" {
#   provider = aws.ap_south_2
#   name     = var.ecsInstanceProfileName
#   role     = var.iamRoleName
# }

# Module calls per region
module "ap_south_2" {

  source                    = "../modules/ecs-ec2-eip"
  region                    = "ap-south-2"
  app_name                  = var.app_name
  image                     = var.image
  ecs_instance_profile_name = var.ecsInstanceProfileName

  providers = {
    aws = aws.ap_south_2
  }

}