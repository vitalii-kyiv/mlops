terraform {
  backend "s3" {
    bucket         = "acme-mlops-tfstate-root"
    key            = "eks-vpc-cluster/root/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "acme-mlops-tf-locks"
    encrypt        = true
  }
}


