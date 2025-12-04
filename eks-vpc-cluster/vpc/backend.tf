terraform {
  backend "s3" {
    bucket         = "acme-mlops-tfstate-vpc"
    key            = "eks-vpc-cluster/vpc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "acme-mlops-tf-locks"
    encrypt        = true
  }
}


