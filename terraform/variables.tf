variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "tenny-eks"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = [] # optional
}

variable "private_subnets" {
  type    = list(string)
  default = [] # optional
}

variable "db_name" {
  type    = string
  default = "tennydb"
}

variable "db_username" {
  type    = string
  default = "tenny"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.small"
}

variable "ecr_repo_name" {
  type    = string
  default = "tenny-django-app"
}

variable "node_group_desired" {
  type    = number
  default = 2
}

variable "node_group_max" {
  type    = number
  default = 3
}

variable "node_group_min" {
  type    = number
  default = 2
}

variable "admin_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "environment" {
  type    = string
  default = "cognitiks"
}

variable "ssh_key_name" {
  type    = string
  default = ""
}