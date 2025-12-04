variable "aws_region" {
  description = "AWS region для розгортання VPC та EKS"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Список AZ у вибраному регіоні"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}


