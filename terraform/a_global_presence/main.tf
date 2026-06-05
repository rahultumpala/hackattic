terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Providers for all 7 regions
provider "aws" {
  region  = "ap-south-2"
  alias   = "ap_south_2"
  profile = var.aws_profile
}
provider "aws" {
  region  = "ap-southeast-1"
  alias   = "ap_southeast_1"
  profile = var.aws_profile
}
provider "aws" {
  region  = "ap-southeast-2"
  alias   = "ap_southeast_2"
  profile = var.aws_profile
}
provider "aws" {
  region  = "ap-northeast-1"
  alias   = "ap_northeast_1"
  profile = var.aws_profile
}
provider "aws" {
  region  = "ap-northeast-2"
  alias   = "ap_northeast_2"
  profile = var.aws_profile
}
provider "aws" {
  region  = "us-east-1"
  alias   = "us_east_1"
  profile = var.aws_profile
}
provider "aws" {
  region  = "eu-west-1"
  alias   = "eu_west_1"
  profile = var.aws_profile
}

# Default VPCs per region
data "aws_vpc" "default_ap_south_2" {
  provider = aws.ap_south_2
  default  = true
}
data "aws_vpc" "default_ap_southeast_1" {
  provider = aws.ap_southeast_1
  default  = true
}
data "aws_vpc" "default_ap_southeast_2" {
  provider = aws.ap_southeast_2
  default  = true
}
data "aws_vpc" "default_ap_northeast_1" {
  provider = aws.ap_northeast_1
  default  = true
}
data "aws_vpc" "default_ap_northeast_2" {
  provider = aws.ap_northeast_2
  default  = true
}
data "aws_vpc" "default_us_east_1" {
  provider = aws.us_east_1
  default  = true
}
data "aws_vpc" "default_eu_west_1" {
  provider = aws.eu_west_1
  default  = true
}

data "aws_subnets" "default_ap_south_2" {
  provider = aws.ap_south_2
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_ap_south_2.id]
  }
}
data "aws_subnets" "default_ap_southeast_1" {
  provider = aws.ap_southeast_1
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_ap_southeast_1.id]
  }
}
data "aws_subnets" "default_ap_southeast_2" {
  provider = aws.ap_southeast_2
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_ap_southeast_2.id]
  }
}
data "aws_subnets" "default_ap_northeast_1" {
  provider = aws.ap_northeast_1
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_ap_northeast_1.id]
  }
}
data "aws_subnets" "default_ap_northeast_2" {
  provider = aws.ap_northeast_2
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_ap_northeast_2.id]
  }
}
data "aws_subnets" "default_us_east_1" {
  provider = aws.us_east_1
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_us_east_1.id]
  }
}
data "aws_subnets" "default_eu_west_1" {
  provider = aws.eu_west_1
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_eu_west_1.id]
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
resource "aws_iam_role" "ecs_instance_role" {
  provider = aws.ap_south_2
  name     = var.iamRoleName
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  provider   = aws.ap_south_2
  role       = var.iamRoleName
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "instance_profile" {
  provider = aws.ap_south_2
  name     = var.ecsInstanceProfileName
  role     = var.iamRoleName
}

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

module "ap_southeast_1" {

  source                    = "../modules/ecs-ec2-eip"
  region                    = "ap-southeast-1"
  app_name                  = var.app_name
  image                     = var.image
  ecs_instance_profile_name = var.ecsInstanceProfileName

  providers = {
    aws = aws.ap_southeast_1
  }

}

module "ap_southeast_2" {

  source                    = "../modules/ecs-ec2-eip"
  region                    = "ap-southeast-2"
  app_name                  = var.app_name
  image                     = var.image
  ecs_instance_profile_name = var.ecsInstanceProfileName

  providers = {
    aws = aws.ap_southeast_2
  }

}

module "ap_northeast_1" {

  source                    = "../modules/ecs-ec2-eip"
  region                    = "ap-northeast-1"
  app_name                  = var.app_name
  image                     = var.image
  ecs_instance_profile_name = var.ecsInstanceProfileName

  providers = {
    aws = aws.ap_northeast_1
  }

}

module "ap_northeast_2" {

  source                    = "../modules/ecs-ec2-eip"
  region                    = "ap-northeast-2"
  app_name                  = var.app_name
  image                     = var.image
  ecs_instance_profile_name = var.ecsInstanceProfileName

  providers = {
    aws = aws.ap_northeast_2
  }

}

module "us_east_1" {

  source                    = "../modules/ecs-ec2-eip"
  region                    = "us-east-1"
  app_name                  = var.app_name
  image                     = var.image
  ecs_instance_profile_name = var.ecsInstanceProfileName

  providers = {
    aws = aws.us_east_1
  }

}

module "eu_west_1" {

  source                    = "../modules/ecs-ec2-eip"
  region                    = "eu-west-1"
  app_name                  = var.app_name
  image                     = var.image
  ecs_instance_profile_name = var.ecsInstanceProfileName

  providers = {
    aws = aws.eu_west_1
  }

}
