variable "aws_region" {
  description = "AWS region для VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR-блок для VPC"
  type        = string
}

variable "vpc_name" {
  description = "Ім'я VPC"
  type        = string
}

variable "azs" {
  description = "Список availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR-блоки для public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR-блоки для private subnets"
  type        = list(string)
}

variable "tags" {
  description = "Додаткові теги"
  type        = map(string)
  default     = {}
}


