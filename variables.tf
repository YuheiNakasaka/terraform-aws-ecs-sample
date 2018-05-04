variable "access_key" {}

variable "secret_key" {}

variable "aws_region" {
  default = "us-east-1"
}

variable "aws_resource_base_name" {
  default = "myapp"
}

variable "aws_ec2_key_name" {
  default = "myapp"
}

variable "aws_ecs_optimized_ami_id" {
  default = "ami-aff65ad2"
}

variable "aws_ecs_service_desired_count" {
  default = "1"
}

variable "aws_autoscaling_group_desired_capacity" {
  default = "1"
}

variable "aws_autoscaling_group_max_size" {
  default = "1"
}

variable "aws_autoscaling_group_min_size" {
  default = "1"
}
