resource "aws_iam_role" "node_iam-example" {
  name = "eks-node-group-example"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

# resource "aws_iam_role_policy_attachment" "node_iam-example-AmazonEKSWorkerNodePolicy" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#   role       = aws_iam_role.example.name
# }

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_iam-example.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_iam-example.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_iam-example.name
}


#resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
#  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#  role    = aws_iam_role.workernodes.name
# }



resource "aws_eks_node_group" "node_example" {
  cluster_name    = aws_eks_cluster.tf_cluster.name
  node_group_name = var.Cluster_Name  #"tf_demo_nodegroup"
  node_role_arn   = aws_iam_role.node_iam-example.arn
#  subnet_ids      = aws_subnet.example[*].id
  subnet_ids   = [aws_subnet.tf_subnet_1.id,aws_subnet.tf_subnet_2.id]
  instance_types = ["${var.InstanceType}"] #["t2.micro"]  
  scaling_config {
    desired_size = var.Desired_Size
    max_size     = var.Max_Size
    min_size     = var.Min_Size #1
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
#   depends_on = [
#     aws_iam_role_policy_attachment.node_iam-example-AmazonEKSWorkerNodePolicy,
#     aws_iam_role_policy_attachment.node_iam-example-AmazonEKS_CNI_Policy,
#     aws_iam_role_policy_attachment.node_iam-example-AmazonEC2ContainerRegistryReadOnly,
#   ]

    depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}