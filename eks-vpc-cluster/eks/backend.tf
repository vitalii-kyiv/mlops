terraform {
  backend "s3" {
    bucket         = "acme-mlops-tfstate-eks"
    key            = "eks-vpc-cluster/eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "acme-mlops-tf-locks"
    encrypt        = true
  }
}


