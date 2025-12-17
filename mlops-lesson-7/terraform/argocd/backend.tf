
terraform {
  backend "local" {
    path = "terraform-argocd.tfstate"
  }
}
