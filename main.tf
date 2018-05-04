provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.aws_region}"
}

# VPC
resource "aws_vpc" "myapp" {
  cidr_block = "10.0.0.0/16"
  tags {
    Name = "myapp"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = "${aws_vpc.myapp.id}"
  tags {
    Name = "myapp-igw"
  }
}

# Subnet Public a
resource "aws_subnet" "myapp_public_a" {
  vpc_id = "${aws_vpc.myapp.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags {
    Name = "myapp_public_a"
  }
}

# Subnet Public c
resource "aws_subnet" "myapp_public_c" {
  vpc_id = "${aws_vpc.myapp.id}"
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1c"
  tags {
    Name = "myapp_public_c"
  }
}

# Routes Table
resource "aws_route_table" "myapp-public-rt" {
  vpc_id = "${aws_vpc.myapp.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.myapp-igw.id}"
  }
  tags {
    Name = "myapp-public-rt"
  }
}

# Routes Table Association a
resource "aws_route_table_association" "myapp-rta-1a" {
  subnet_id = "${aws_subnet.myapp_public_a.id}"
  route_table_id = "${aws_route_table.myapp-public-rt.id}"
}

# Routes Table Association c
resource "aws_route_table_association" "myapp-rta-1c" {
  subnet_id = "${aws_subnet.myapp_public_c.id}"
  route_table_id = "${aws_route_table.myapp-public-rt.id}"
}

# Security Group
resource "aws_security_group" "myapp" {
  name        = "${var.aws_resource_base_name}"
  description = "${var.aws_resource_base_name}"
  vpc_id      = "${aws_vpc.myapp.id}"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

# Launch Config
resource "aws_launch_configuration" "myapp" {
  associate_public_ip_address = true
  depends_on                  = ["aws_internet_gateway.myapp-igw"]
  name                        = "${var.aws_resource_base_name}"
  image_id                    = "${var.aws_ecs_optimized_ami_id}"
  instance_type               = "t2.micro"
  security_groups             = ["${aws_security_group.myapp.id}"]
  iam_instance_profile        = "${aws_iam_instance_profile.myapp.id}"
  user_data                   = "#!/bin/bash\necho ECS_CLUSTER='${aws_ecs_cluster.myapp.name}' >> /etc/ecs/ecs.config"
}

# Auto Scaling Group
resource "aws_autoscaling_group" "myapp" {
  name                 = "${var.aws_resource_base_name}"
  launch_configuration = "${aws_launch_configuration.myapp.name}"
  desired_capacity     = "${var.aws_autoscaling_group_desired_capacity}"
  min_size             = "${var.aws_autoscaling_group_max_size}"
  max_size             = "${var.aws_autoscaling_group_min_size}"
  health_check_type    = "EC2"
  vpc_zone_identifier  = ["${aws_subnet.myapp_public_a.id}", "${aws_subnet.myapp_public_c.id}"]

  tag {
    key                 = "Name"
    value               = "${var.aws_resource_base_name}"
    propagate_at_launch = true
  }
}

# ALB
resource "aws_alb" "myapp" {
  name            = "${var.aws_resource_base_name}"
  security_groups = ["${aws_security_group.myapp.id}"]
  subnets         = ["${aws_subnet.myapp_public_a.id}", "${aws_subnet.myapp_public_c.id}"]
}

# ALB Listner
resource "aws_alb_listener" "myapp" {
  load_balancer_arn = "${aws_alb.myapp.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.myapp.id}"
    type             = "forward"
  }
}

# ALB Target
resource "aws_alb_target_group" "myapp" {
  name     = "${var.aws_resource_base_name}"
  protocol = "HTTP"
  port     = 80
  vpc_id   = "${aws_vpc.myapp.id}"

  deregistration_delay = 10

  health_check {
    path                = "/"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  stickiness {
    enabled = false
    type = "lb_cookie"
  }
}

# IAM For ECS instance
resource "aws_iam_role" "ecs_instance_role" {
    name = "ecs_instance_role"
    assume_role_policy = <<-JSON
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Effect": "Allow",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          }
        }
      ]
    }
    JSON
}

# IAM For ECS service
resource "aws_iam_role" "ecs_service_role" {
    name = "ecs_service_role"
    assume_role_policy = <<-JSON
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Effect": "Allow",
          "Principal": {
            "Service": "ecs.amazonaws.com"
          }
        }
      ]
    }
    JSON
}

# Attach IAM policy to ECS instance
resource "aws_iam_policy_attachment" "myapp_ecs_instance_role_attach" {
    name = "${var.aws_resource_base_name}-ecs-instance-role-attach"
    roles = ["${aws_iam_role.ecs_instance_role.name}"]
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Attach IAM policy to ECS service
resource "aws_iam_policy_attachment" "myapp_ecs_service_role_attach" {
    name = "${var.aws_resource_base_name}-ecs-service-role-attach"
    roles = ["${aws_iam_role.ecs_service_role.name}"]
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

# Attach IAM policy to EC2 instance
resource "aws_iam_instance_profile" "myapp" {
    name = "${var.aws_resource_base_name}"
    role = "${aws_iam_role.ecs_instance_role.name}"
}

# ECS Cluster
resource "aws_ecs_cluster" "myapp" {
  name = "${var.aws_resource_base_name}"
}

# ECS Service
resource "aws_ecs_service" "myapp" {
  cluster                            = "${aws_ecs_cluster.myapp.id}"
  deployment_minimum_healthy_percent = 50
  desired_count                      = "${var.aws_ecs_service_desired_count}"
  iam_role                           = "${aws_iam_role.ecs_service_role.arn}"
  name                               = "${var.aws_resource_base_name}"
  task_definition                    = "${aws_ecs_task_definition.myapp.arn}"
  load_balancer {
    container_name   = "${var.aws_resource_base_name}"
    container_port   = "80"
    target_group_arn = "${aws_alb_target_group.myapp.arn}"
  }
}

# ECS Task
resource "aws_ecs_task_definition" "myapp" {
  family = "${var.aws_resource_base_name}"

  container_definitions = <<-JSON
  [
    {
      "name": "${var.aws_resource_base_name}",
      "image": "nginx",
      "cpu": 1024,
      "memory": 200,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ]
    }
  ]
  JSON
}

# CloudWatch
resource "aws_cloudwatch_log_group" "myapp" {
  name = "${var.aws_resource_base_name}"
}
