resource "aws_vpc" "tf_vpc" {
  cidr_block       = "${var.CIDR_Block}"
  instance_tenancy = "default"

  tags = {
    Name = "${var.VPC_Name}"
  }
}


resource "aws_subnet" "tf_subnet_1" {
  vpc_id     = aws_vpc.tf_vpc.id
  cidr_block = var.Subnet1_CIDR #"20.0.1.0/24"
  availability_zone = "us-east-2a"  
  map_public_ip_on_launch = "true"  
  tags = {
    Name = "tf__demo_subnet_1"
  }
}

resource "aws_subnet" "tf_subnet_2" {
  vpc_id     = aws_vpc.tf_vpc.id
  cidr_block = var.Subnet2_CIDR  #"${var. }"
  availability_zone = "us-east-2b"
  map_public_ip_on_launch = "true"  #enable auto-assign public IP address


  tags = {
    Name = "tf__demo_subnet_2"
  }
}


resource "aws_internet_gateway" "tf_gw" {
  vpc_id = aws_vpc.tf_vpc.id

  tags = {
    Name = "tf_demo_gw"
  }
}


resource "aws_route_table" "tf_rtb" {
  vpc_id = aws_vpc.tf_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf_gw.id
  }

   tags = {
    Name = "tf_demo_rtb"
  }
}

resource "aws_route_table_association" "tf_rtb_ass_subnet_1" {
  subnet_id      = aws_subnet.tf_subnet_1.id
  route_table_id = aws_route_table.tf_rtb.id
}

resource "aws_route_table_association" "tf_rtb_ass_subnet_2" {
  subnet_id      = aws_subnet.tf_subnet_2.id
  route_table_id = aws_route_table.tf_rtb.id
}


resource "aws_security_group" "tf_sg" {
  name        = "tf_demo_sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.tf_vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] #[aws_vpc.tf_vpc.cidr_block]
    ipv6_cidr_blocks = ["::/0"] #[aws_vpc.tf_vpc.ipv6_cidr_block]
  }

    ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] #[aws_vpc.tf_vpc.cidr_block]
    ipv6_cidr_blocks = ["::/0"] #[aws_vpc.tf_vpc.ipv6_cidr_block]
  }



  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.Security_Group_Name}"
  }
}
