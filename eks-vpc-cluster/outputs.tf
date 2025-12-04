output "vpc_id" {
  description = "ID створеної VPC"
  value       = module.vpc.vpc_id
}

output "vpc_private_subnets" {
  description = "Private subnets VPC (для EKS worker-ів)"
  value       = module.vpc.private_subnets
}

output "eks_cluster_name" {
  description = "Ім'я EKS кластера"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint EKS кластера"
  value       = module.eks.cluster_endpoint
}


