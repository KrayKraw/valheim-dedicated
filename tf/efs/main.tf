terraform {
  required_version = "0.15.0"

  backend "s3" {
    bucket               = "kraykray-terraform"
    workspace_key_prefix = "valheim"
    key                  = "efs/terraform.tfstate"
    region               = "us-west-1"
    encrypt              = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>3.0"
    }
  }
}

locals {
  vpc_id          = "vpc-ddde07bb"
  subnet_id_uws1b = "subnet-c88e2a92"
}

provider "aws" {
  region = "us-west-1"
}

# EFS Setup

resource "aws_security_group" "mount_nfs_sg" {
  name        = "allow_inbound_nfs_fs"
  description = "allows inbound nfs access for the valheim efs filesystem"
  vpc_id      = local.vpc_id

  ingress {
    protocol  = "TCP"
    from_port = 2049
    to_port   = 2049
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_efs_file_system" "fs" {
  creation_token = "valheim-efs"

  tags = {
    Name = "EFS for valheim"
  }
}

resource "aws_efs_mount_target" "mount" {
  file_system_id  = aws_efs_file_system.fs.id
  subnet_id       = local.subnet_id_uws1b
  security_groups = [aws_security_group.mount_nfs_sg.id]
}

