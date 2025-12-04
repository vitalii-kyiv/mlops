output "cluster_name" {
  description = "Ім'я EKS кластера"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API endpoint EKS кластера"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security Group ID для EKS кластера"
  value       = module.eks.cluster_security_group_id
}


