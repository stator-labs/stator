terraform {
  required_version = "~> 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }

  # Bucket comes from `-backend-config=bucket=...` so the account ID is never in code.
  backend "s3" {
    key          = "00-ground-rules/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      project            = "runway"
      lab                = "00"
      "runway:ephemeral" = "false"
    }
  }
}
