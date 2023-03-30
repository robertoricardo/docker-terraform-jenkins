terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.59.0"
    }
  }
}

// Access e Secret keys para acesso a AWS e EC2
provider "aws" {
  region = "us-east-1"
  access_key = var.my_access_key 
  secret_key = var.my_secret_key 
}

# Default VPC
resource "aws_vpc" "app-vpc" {
  cidr_block = var.vpc_cidr_blocks
  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "app-subnet" {
  vpc_id = aws_vpc.app-vpc.id
  cidr_block = var.subnet_cidr_blocks
  availability_zone = var.avail_zone
  tags = {
    Name = "${var.env_prefix}-subnet-1"
  }
}

// Cria o internet gateway para receber conexões da internet
resource "aws_internet_gateway" "app-igw" {
  vpc_id = aws_vpc.app-vpc.id
  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

// Route table de acordo com a VPC criada
resource "aws_default_route_table" "main-rtb" {
  default_route_table_id = aws_vpc.app-vpc.default_route_table_id 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app-igw.id
  }
  tags = {
    Name = "${var.env_prefix}-rtb"
  } 
}

resource "aws_default_security_group" "default-sg" {
//  name = "app-sg"  // Para uso de um security group personalizado
  vpc_id = aws_vpc.app-vpc.id

// Tráfego de entrada
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.my_ip] // Para permitir a conexão somente a partir do meu ip
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] // Permite conexões da internet
  }
// Tráfego de saída
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  tags = {
    Name = "${var.env_prefix}-default-sg"
  }

}

resource "aws_key_pair" "ssh_key" {
  key_name = "server-key"
  public_key = file(var.public_key_location)
}


# Instância t2.micro 
resource "aws_instance" "app-server" {
  ami = "ami-02f3f602d23f1659d"  //"ami-02f3f602d23f1659d"
  instance_type = var.instance_type
  
  subnet_id = aws_subnet.app-subnet.id
  vpc_security_group_ids = [aws_default_security_group.default-sg.id]
  availability_zone = var.avail_zone

  associate_public_ip_address = true
  key_name = aws_key_pair.ssh_key.key_name

  tags = {
    "Name" = "${var.env_prefix}-server"
  }

}
