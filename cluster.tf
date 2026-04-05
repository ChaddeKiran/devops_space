data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "example" {
  name               = "tf_iam_role_cluster"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.example.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "example-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.example.name
}


resource "aws_eks_cluster" "tf_cluster" {
  name     = var.Cluster_Name   #"tf_demo_cluster"
  role_arn = aws_iam_role.example.arn

  vpc_config {
    
    subnet_ids =[aws_subnet.tf_subnet_1.id, aws_subnet.tf_subnet_2.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
  ]
}

output "endpoint" {
  value = aws_eks_cluster.tf_cluster.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.tf_cluster.certificate_authority[0].data
}


#  resource "aws_eks_node_group" "worker-node-group" {
#   cluster_name  = aws_eks_cluster.my-eks.name
#   node_group_name = "my-workernodes"
#   node_role_arn  = aws_iam_role.workernodes.arn
#   subnet_ids   = [var.subnet_id_1, var.subnet_id_2]
#   instance_types = ["t2.small"]

#   scaling_config {
#    desired_size = 2
#    max_size   = 2
#    min_size   = 1
#   }

#   depends_on = [
#    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
#    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
#    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
#   ]
#  }

