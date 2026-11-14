terraform {
  required_version = "~> 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }

  # Bucket comes from `-backend-config=bucket=...` so the account ID is never in code.
  # On the first run, bootstrap.sh shadows this with a local backend (local_override.tf),
  # then migrates the state here.
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project            = "runway"
      lab                = "00"
      "runway:ephemeral" = "false"
      "runway:stack"     = "bootstrap"
    }
  }
}
