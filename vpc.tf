provider "aws"{
  region    = "ap-south-1"
  profile   = "AWS"
}


resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  enable_dns_hostnames = "true"
  instance_tenancy = "default"
  tags = {
    Name = "test-vpc"
  }
}


resource "aws_internet_gateway" "igw" {

  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "test_gw"
  }
}
resource "aws_subnet" "public" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
  
  tags = {
    Name = "private"
  }
}

resource "aws_route_table" "route" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }


  tags = {
    Name = "routetable"
  }
}
resource "aws_route_table_association" "publicsubnet" {
  
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.route.id}"
}



resource "aws_security_group" "sg_public" {
  name        = "vpc_sg"
  description = "Allow HTTP , SSH and ICMP"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "icmp"
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_public"
  }
}

resource "aws_instance" "wordpress" {
  ami           = "ami-ff82f990"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  subnet_id = "${aws_subnet.public.id}"
  vpc_security_group_ids = [aws_security_group.sg_public.id]
  key_name = "rhel8key"

  tags = {
    Name = "wordpress"
    }
  } 


resource "aws_security_group" "sg_private" {

  name        = "sg_private"
  description = "Allow wordpress inbound traffic"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {

    description = "Allow only wordpress"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.sg_public.id]
}
  
    ingress {

    description = "Allow wordpress ping"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    security_groups = [aws_security_group.sg_public.id]
}

    egress {
      
      from_port=0
      to_port=0
      protocol="-1"
      cidr_blocks=["0.0.0.0/0"]
      ipv6_cidr_blocks =  ["::/0"]
}

  tags = {
    Name = "sg_private"
  }
}

  resource "aws_instance" "mysql-private" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg_private.id]
  key_name = "rhel8key"
  subnet_id = "${aws_subnet.private.id}"

  tags = {
    Name = "mysql"
    }
}