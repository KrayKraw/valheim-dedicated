terraform {
  required_version = "0.15.0"

  backend "s3" {
    bucket               = "kraykray-terraform"
    workspace_key_prefix = "valheim"
    key                  = "servers/valheim1/terraform.tfstate"
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
  efs_fs_id = "fs-2b31dd33"
}

provider "aws" {
  region = "us-west-1"
}

variable server_password {
  description = "Password for the server"
}

module "server_one" {
  source = "../../servermodule"
  name   = "server_one"
  long_name = "Emm's house"
  world_file = "Cathalla"
  server_password = var.server_password
  cpu = 1024
  memory = 2048
  efs_fs_id = local.efs_fs_id
}