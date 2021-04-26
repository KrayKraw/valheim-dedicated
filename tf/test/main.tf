terraform {
  required_version = "0.15.0"

  backend s3 {
    bucket = "kraykray-terraform"
    workspace_key_prefix = "valheim"
    key = "testing/terraform.tfstate"
    region = "us-west-1"
    encrypt = true
  }

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~>3.0"
    }
  }
}

provider aws {
  region = "us-west-1"
}

resource aws_ebs_volume example {
  availability_zone = "us-west-1b"
  size              = 5

  tags = {
    Name = "HelloWorld"
  }
}