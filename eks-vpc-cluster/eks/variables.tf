variable "aws_region" {
  description = "AWS region для EKS кластера"
  type        = string
}

variable "cluster_name" {
  description = "Ім'я EKS кластера"
  type        = string
}

variable "vpc_state_bucket" {
  description = "S3 bucket, де зберігається state VPC (для terraform_remote_state)"
  type        = string
}

variable "vpc_state_key" {
  description = "Шлях (key) до VPC state в S3"
  type        = string
}

variable "vpc_state_region" {
  description = "Регіон S3 bucket з VPC state"
  type        = string
}

variable "common_tags" {
  description = "Спільні теги для всіх EKS ресурсів"
  type        = map(string)
  default     = {}
}

variable "cpu_node_group_min_size" {
  description = "Мінімальна кількість нод у CPU node group"
  type        = number
  default     = 1
}

variable "cpu_node_group_max_size" {
  description = "Максимальна кількість нод у CPU node group"
  type        = number
  default     = 2
}

variable "cpu_node_group_desired_size" {
  description = "Бажана кількість нод у CPU node group"
  type        = number
  default     = 1
}

variable "gpu_node_group_min_size" {
  description = "Мінімальна кількість нод у GPU node group (умовно, насправді free-tier інстанси без GPU)"
  type        = number
  default     = 1
}

variable "gpu_node_group_max_size" {
  description = "Максимальна кількість нод у GPU node group"
  type        = number
  default     = 1
}

variable "gpu_node_group_desired_size" {
  description = "Бажана кількість нод у GPU node group"
  type        = number
  default     = 1
}


