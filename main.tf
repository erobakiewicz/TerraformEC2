terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "vpc" {
  name    = "prediction-vpc"
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.19.0"

  azs                = var.availability_zones
  cidr               = "10.0.0.0/16"
  create_igw         = true
  enable_nat_gateway = true
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"]
}

resource "aws_security_group" "myapp-sg" {
  vpc_id = module.vpc.vpc_id
  name   = "ec2-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "ec2-default-sg"
  }
}

resource "aws_key_pair" "ssh-key" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}


resource "aws_instance" "myapp-server" {
  ami           = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type

  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  availability_zone      = "eu-central-1a"

  associate_public_ip_address = true
  key_name                    = aws_key_pair.ssh-key.key_name

  tags = {
    Name = "ec2-server"
  }
}