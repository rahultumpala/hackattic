terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "app_name" {}
variable "image" {}
variable "region" {}
variable "ecs_instance_profile_name" {}

# ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  provider = aws
  name     = "${var.app_name}-cluster"
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "ecs_http" {
  name        = "ecs-http-sg"
  description = "Allow HTTP to ECS EC2 instances"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ECS EC2 instance
data "aws_ami" "ecs_ami" {
  provider    = aws
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-arm64-ebs"]
  }
}

resource "aws_instance" "ecs_ec2" {
  provider                    = aws
  ami                         = data.aws_ami.ecs_ami.id
  instance_type               = "t4g.micro"
  associate_public_ip_address = true
  iam_instance_profile        = var.ecs_instance_profile_name

  vpc_security_group_ids = [
    aws_security_group.ecs_http.id
  ]

  user_data = <<EOF
#!/bin/bash
echo "ECS_CLUSTER=${aws_ecs_cluster.cluster.name}" >> /etc/ecs/ecs.config
EOF
}

# Elastic IP
resource "aws_eip" "ecs_eip" {
  provider = aws
  instance = aws_instance.ecs_ec2.id
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app_task" {
  provider                 = aws
  family                   = var.app_name
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = var.image
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:80/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "app_service" {
  provider        = aws
  name            = var.app_name
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "EC2"
}
