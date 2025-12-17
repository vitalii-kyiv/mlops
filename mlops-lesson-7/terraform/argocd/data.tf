
data "aws_eks_cluster" "cluster" {
  name = "goit-eks"
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.aws_eks_cluster.cluster.name
}






