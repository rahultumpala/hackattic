output "ecr_repository" {
  value = var.create_ecr ? aws_ecr_repository.app[0].repository_url : "<account-number>.dkr.ecr.ap-south-2.amazonaws.com"
}

output "ec2_ips" {
  description = "Public IPs of all EC2 instances"
  value = {
    "ap-south-2"     = module.ap_south_2.ecs_instance_public_ip
    "ap-southeast-1" = module.ap_southeast_1.ecs_instance_public_ip
    "ap-southeast-2" = module.ap_southeast_2.ecs_instance_public_ip
    "ap-northeast-1" = module.ap_northeast_1.ecs_instance_public_ip
    "ap-northeast-2" = module.ap_northeast_2.ecs_instance_public_ip
    "us-east-1" = module.us_east_1.ecs_instance_public_ip
    "eu-west-1" = module.eu_west_1.ecs_instance_public_ip
  }
}