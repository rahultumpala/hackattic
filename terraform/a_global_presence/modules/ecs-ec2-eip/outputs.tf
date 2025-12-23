output "ecs_instance_public_ip" {
  value = aws_eip.ecs_eip.public_ip
}