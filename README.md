# MySQL-and-Wordpress-architecture-on-AWS-instances-without-NAT-gateway
![alt text](https://2.bp.blogspot.com/-M5mou_8yyl4/XDLK-2xxWtI/AAAAAAAACeI/f4o3_L2PzP0Q8lVqzpAJ4W25GMdQzUOSwCLcBGAs/s1600/sample%2Bvpc.jpg)

**Project Description**
-Steps:
- Write a Infrastructure as code using terraform, which automatically create a VPC.

-  In that VPC we have to create 2 subnets:
    a)  public  subnet [ Accessible for Public World! ] 
    b)  private subnet [ Restricted for Public World! ]

- Create a public facing internet gateway for connect our VPC/Network to the internet world and attach this gateway to our VPC.

-  Create  a routing table for Internet gateway so that instance can connect to outside world, update and associate it with public subnet.

-  Launch an ec2 instance which has Wordpress setup already having the security group allowing  port 80 so that our client can connect to our wordpress site.
Also attach the key to instance for further login into it.

-  Launch an ec2 instance which has MYSQL setup already with security group allowing  port 3306 in private subnet so that our wordpress vm can connect with the same.
Also attach the key with the same.


# Let's understand some of the basic things

# What is Wordpress and MySQL architecture?
-MySQL is a database management system that is used by WordPress to store and retrieve all your blog information. Think of it this way. If your database is a filing cabinet that WordPress uses to organize and store all the important data from your website (posts, pages, images, etc), then MySQL is the company that created this special type of filing cabinet.

-MySQL is an open source relational database management system. It runs as a server and allows multiple users to manage and create numerous databases. It is a central component in the LAMP stack of open source web application software that is used to create websites. LAMP stands for Linux, Apache, MySQL, and PHP. Most WordPress installations use the LAMP stack because it is open source and works seamlessly with WordPress.

-WordPress requires MySQL to store and retrieve all of its data including post content, user profiles, and custom post types. Most web hosting providers already have MySQL installed on their web servers as it is widely used in many open source web applications such as WordPress.


**After Knowing these  Let's start our project**

**Step 1**

Initially , I have created a user in my AWS account with limited power . This user doesn't have a root access  so it  won't be able to able to create other user and see the billing dashboard 
![Job1](/images/USER.jpg/)

**Step 2**

Now I login to my AWS account with the User  to perform task

![Job1](/images/1.jpg/)

**Step 3**

Now after logging in run ```terraform init``` to  initialize the local directory  and it also checks the .tf file and download the required plugins


**Step 4**
And  now we run  ```terraform apply --auto-approve``` to create the required infrastructure in just one command

![Job1](/images/2.jpg/)

**Step 5**
So here our infrastructure is created let's look at its components and code used for it 

- Here we provide information about the provider , the profile and the availibility zone 
```
  provider "aws"{
  region    = "ap-south-1"
  profile   = "AWS"
}
```

- Here is the VPC 
  Amazon Virtual Private Cloud (Amazon VPC) lets you provision a logically isolated section of the AWS Cloud where you can launch AWS resources in a virtual network that you define
```
  resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  enable_dns_hostnames = "true"
  instance_tenancy = "default"
  tags = {
    Name = "test-vpc"
  }
}
```
![Job1](/images/VPC.jpg/)

- Then after VPC I have created Internet Gateway so that the public instance can connect to outside world
```resource "aws_internet_gateway" "igw" {

  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "test_gw"
  }
}
```
![Job1](/images/IGW.jpg/)

- Now here is our Private and Public Subnets
```
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
```

- Private Subnet
![Private](/images/private.jpg/)

- Public Subnet
![Public](/images/Public.jpg/)

- Route table
  A route table contains a set of rules, called routes, that are used to determine where network traffic from your subnet or gateway is directed and I have attached it to public subnet
 ```
  resource "aws_route_table" "public_route" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }


  tags = {
    Name = "pubic_routetable"
  }
}

resource "aws_route_table_association" "public_subnet_asso" {
  
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public_route.id}"
  depends_on = [aws_route_table.public_route , aws_subnet.public]
}
```  


- Now I have created the security groups for the instances
  - For Wordpress instance
```
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
```

- For MySQL Instance

```
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
```


  ![SG](/images/SG.jpg/)
  
  - Here is our instances of Wordpress and MySQL
    - Wordpress Instance
  ```
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
  ```
   - MySQL Instance
  
```
   resource "aws_instance" "mysql-private" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.sg_private.id]
  key_name = "rhel8key"
  subnet_id = "${aws_subnet.private.id}"

  tags = {
    Name = "mysql"
    }
}

```
 ![Nat](/images/Instance.jpg/)

**Here is our Instance in Public Subnet able to ping outside World**
 ![Nat](/images/Bitnami.jpg/)

**Now when we connect to the public ip of wordpress instance it opens the Wordpress**

 ![Nat](/images/3.jpg/)
 
 
 # Thank You :-)
 
  
