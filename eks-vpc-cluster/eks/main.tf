data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.vpc_state_bucket
    key    = var.vpc_state_key
    region = var.vpc_state_region
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnets

  enable_irsa = true

  eks_managed_node_groups = {
    cpu = {
      desired_size = var.cpu_node_group_desired_size
      max_size     = var.cpu_node_group_max_size
      min_size     = var.cpu_node_group_min_size

      instance_types = ["t3.micro"]
      capacity_type  = "ON_DEMAND"
    }

    gpu = {
      desired_size = var.gpu_node_group_desired_size
      max_size     = var.gpu_node_group_max_size
      min_size     = var.gpu_node_group_min_size

      instance_types = ["t3.micro"]
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = var.common_tags
}


