provider "aws" {
  region = "us-east-1"
}
# Creating VPC
resource "aws_vpc" "demovpc" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Name = "tf- VPC"
  }
}
# Creating Internet Gateway
resource "aws_internet_gateway" "demogateway" {
  vpc_id = aws_vpc.demovpc.id
  tags = {
    Name = "tf-IGW"
  }
}
# Creating 1st web subnet
resource "aws_subnet" "public-subnet-1" {
  vpc_id                  = aws_vpc.demovpc.id
  cidr_block              = "192.168.100.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "tf-public-sn-1"
  }
}
# Creating 2nd web subnet
resource "aws_subnet" "public-subnet-2" {
  vpc_id                  = aws_vpc.demovpc.id
  cidr_block              = "192.168.200.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1d"
  tags = {
    Name = "tf-public-sn-2"
  }
}
# Creating Route Table
resource "aws_route_table" "Publicroute" {
  vpc_id = aws_vpc.demovpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demogateway.id
  }
  tags = {
    Name = "tf-rt"
  }
}
# Creating Security Group
 resource "aws_security_group" "demosg" {
  vpc_id = "${aws_vpc.demovpc.id}"
# Inbound Rules
# HTTP access from anywhere 
ingress {
  from_port = 80
  to_port   = 80
  protocol  = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
# HTTPS access from anywhere
ingress {
  from_port = 443
  to_port   = 443
  protocol  = "tcp"
  cidr_blocks =["0.0.0.0/0"]
}
# SSH access from anywhere
ingress {
  from_port = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks =["0.0.0.0/0"]
}
# Outbound Rules
# Internet access from anywhere
egress {
  from_port = 0
  to_port   = 0
  protocol  = "-1"
  cidr_blocks =["0.0.0.0/0"]
}
tags = {
 Name = "Web SG"
}
}
# Association Route Table
resource "aws_route_table_association" "route-sub" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.Publicroute.id
}

# Association Route Table
resource "aws_route_table_association" "route-sub2" {
  subnet_id      = aws_subnet.public-subnet-2.id
  route_table_id = aws_route_table.Publicroute.id
}
# Creating key_pair to attach EC2 Instance
resource "aws_key_pair" "key-pair" {
  key_name   = "master"
  public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}
resource "local_file" "key-pair" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "master"
}
# Create 1st EC2 instance in Public Subnet1
 resource "aws_instance" "instance" {
     ami           = "ami-05fa00d4c63e32376"
     instance_type = "t2.micro"
     key_name      = "master"
     vpc_security_group_ids = ["${aws_security_group.demosg.id}"]
     subnet_id              ="${aws_subnet.public-subnet-1.id}"
     associate_public_ip_address =true
     user_data = "${file("data.sh")}"
tags = {
 Name = "Instance1"
   }
}
# Create 2nd EC2 instance in Public Subnet2
 resource "aws_instance" "demoinstance1" {
     ami           = "ami-05fa00d4c63e32376"
     instance_type = "t2.micro"
     key_name      = "master"
     vpc_security_group_ids =["${aws_security_group.demosg.id}"]
     subnet_id              ="${aws_subnet.public-subnet-2.id}"
     associate_public_ip_address =true
     user_data            ="${file("data1.sh")}"
tags = {
     Name = "Instance2"
}
}
resource "aws_lb_target_group" "target-elb" {
  name     = "elb-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demovpc.id
}
# Creating External LoadBalancer
resource "aws_lb" "external-elb" {
  name               = "Load-Balancer"
  internal           = "false"
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.demosg.id}"]
  subnets            = ["${aws_subnet.public-subnet-1.id}", "${aws_subnet.public-subnet-2.id}"]
}
# Attach the target group to load balaner
resource "aws_lb_target_group_attachment" "attachment" {
  target_group_arn = aws_lb_target_group.target-elb.arn
  target_id        = aws_instance.instance.id
  port             = "80"
  depends_on = [
    aws_instance.instance
  ]
}
resource "aws_lb_target_group_attachment" "attachment1" {
  target_group_arn = aws_lb_target_group.target-elb.arn
  target_id        = aws_instance.demoinstance1.id
  port             = 80
  depends_on = [
    aws_instance.demoinstance1
  ]
}
resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.external-elb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-elb.arn
  }
}
# Getting the DNS of load balancer
output "lb_dns_name" {
   description = "The DNS name of the load balancer"
   value = "${aws_lb.external-elb.dns_name}"
}







