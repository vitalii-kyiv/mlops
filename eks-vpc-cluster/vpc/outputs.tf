output "vpc_id" {
  description = "ID створеної VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Public subnets VPC"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Private subnets VPC"
  value       = module.vpc.private_subnets
}

output "vpc_cidr_block" {
  description = "CIDR-блок VPC"
  value       = module.vpc.vpc_cidr_block
}


