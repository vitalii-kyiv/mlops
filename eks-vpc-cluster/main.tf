locals {
  project_name = "demo-eks-vpc-cluster"

  vpc_name     = "${local.project_name}-vpc"
  cluster_name = "${local.project_name}-cluster"

  tags = {
    Project     = local.project_name
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "./vpc"

  aws_region          = var.aws_region
  vpc_cidr            = "10.0.0.0/16"
  azs                 = var.availability_zones
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = [
    "10.0.101.0/24",
    "10.0.102.0/24"
  ]

  vpc_name = local.vpc_name
  tags     = local.tags
}

module "eks" {
  source = "./eks"

  aws_region   = var.aws_region
  cluster_name = local.cluster_name

  vpc_state_bucket = "acme-mlops-tfstate-vpc"
  vpc_state_key    = "eks-vpc-cluster/vpc/terraform.tfstate"
  vpc_state_region = var.aws_region

  common_tags = local.tags

  cpu_node_group_min_size     = 1
  cpu_node_group_max_size     = 2
  cpu_node_group_desired_size = 1

  gpu_node_group_min_size     = 1
  gpu_node_group_max_size     = 1
  gpu_node_group_desired_size = 1
}


