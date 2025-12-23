variable "create_ecr" {
  type    = bool
  default = false
}

variable "create_ecs_iam_role" {
  type    = bool
  default = false
}

variable "app_name" {
  type        = string
  description = "Name of the application"
  default = "hacakttic"
}

variable "image" {
  type        = string
  description = "ECR image URI to deploy"
  default = "<account-number>.dkr.ecr.<region>.amazonaws.com/hacakttic:global_presence"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile to use for all regions"
  default     = "hackattic"
}

variable "primary_region" {
  type = string
  default = "ap-south-2"
  description = "Region in which ECR repo will be created"
}

variable "ecsInstanceProfileName" {
  type = string
  default = "ecsInstanceProfile"
}

variable "iamRoleName" {
  type = string
  default = "ecsInstanceRole"
}