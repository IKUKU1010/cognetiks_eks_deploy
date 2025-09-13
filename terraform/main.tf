locals {
  name = var.cluster_name
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

# -------------------
# VPC
# -------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = length(var.public_subnets) > 0 ? var.public_subnets : ["10.0.1.0/24","10.0.2.0/24"]
  private_subnets = length(var.private_subnets) > 0 ? var.private_subnets : ["10.0.11.0/24","10.0.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# -------------------
# ECR
# -------------------
resource "aws_ecr_repository" "app" {
  name = var.ecr_repo_name
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -------------------
# RDS (Postgres)
# -------------------
resource "aws_db_subnet_group" "default" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
  tags = { Name = "${local.name}-db-subnet-group" }
}

resource "aws_security_group" "rds_sg" {
  name        = "${local.name}-rds-sg"
  description = "Allow DB access from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15.7"
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  port                   = 5432
  db_subnet_group_name   = aws_db_subnet_group.default.name
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

# -------------------
# Security Groups
# -------------------
resource "aws_security_group" "eks_nodes_sg" {
  name   = "${local.name}-eks-nodes-sg"
  vpc_id = module.vpc.vpc_id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow EKS nodes to talk to RDS
resource "aws_security_group_rule" "eks_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.eks_nodes_sg.id
}

# Allow SSH access to nodes (22/tcp) from your IP
resource "aws_security_group_rule" "ssh_access" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.admin_cidr]
  security_group_id = aws_security_group.eks_nodes_sg.id
}

# -------------------
# EKS
# -------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name
  cluster_version = "1.29"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      desired_size = var.node_group_desired
      max_size     = var.node_group_max
      min_size     = var.node_group_min
      instance_types = ["t3.small"]
      key_name      = var.ssh_key_name != "" ? var.ssh_key_name : null
      additional_security_group_ids = [aws_security_group.eks_nodes_sg.id]
    }
  }

  # Enable cluster access
  cluster_endpoint_public_access = true
}

# -------------------
# S3 Bucket for Django static/media
# -------------------
resource "aws_s3_bucket" "django_static" {
  bucket = "${local.name}-django-static"
  force_destroy = true

  tags = {
    Name        = "${local.name}-django-static"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.django_static.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.django_static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "django_s3_policy" {
  name        = "${local.name}-django-s3-policy"
  description = "Allow app to upload static/media files to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = ["${aws_s3_bucket.django_static.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.django_static.arn]
      }
    ]
  })
}

# -------------------
# Outputs
# -------------------
output "kubeconfig_cluster_name" {
  value = module.eks.cluster_id
}
output "kubeconfig_endpoint" {
  value = module.eks.cluster_endpoint
}
output "kubeconfig_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}
output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}
output "rds_port" {
  value = aws_db_instance.postgres.port
}
output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}
output "s3_bucket_name" {
  value = aws_s3_bucket.django_static.bucket
}
output "s3_bucket_arn" {
  value = aws_s3_bucket.django_static.arn
}
output "vpc_id" {
  value = module.vpc.vpc_id
}
output "private_subnets" {
  value = module.vpc.private_subnets
}
