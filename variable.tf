variable "AWS_Region" {
  type = string
  default = "ap-south-1"
}

variable "Cluster_Name" {
  type    = string
  default = "Tf_project_cluster"
}

variable "NodeGroup_Name" {
  type    = string
  default = "Tf_nodeproup"
}

# variable "Subnet_ids" {
#   type    = list(string)
#   #default = ["aws", "subnet_id_2"]
#   default = ["aws_subnet.tf_subnet_1.id","aws_subnet.tf_subnet_2.id"]
# }


variable "InstanceType" {
    type = string
    default = "t2.micro"
}

variable "Desired_Size" {
  type = number
  default = 2 
}
variable "Min_Size" {
  type = number
  default = 1 
}
variable "Max_Size" {
  type = number
  default = 3 
}


#vpc and subnet

variable "VPC_Name" {
  type = string
  default = "Tf_vpc"
}

variable "CIDR_Block" {
  type = string
  default = "20.0.0.0/16"

}

variable "Subnet1_CIDR" {
  type = string
  default = "20.0.1.0/24"
}

variable "Subnet2_CIDR" {
  type = string
  default = "20.0.2.0/24"
}

variable "Security_Group_Name" {
  type = string
  default = "Tf_security_grouop"
}