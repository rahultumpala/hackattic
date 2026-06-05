output "ecr_repository" {
  value = var.create_ecr ? aws_ecr_repository.app[0].repository_url : "account-id.dkr.ecr.ap-south-2.amazonaws.com"
}

output "ec2_ips" {
  description = "Public IPs of all EC2 instances"
  value = {
    "ap-south-2"     = module.ap_south_2.ecs_instance_public_ip
  }
}