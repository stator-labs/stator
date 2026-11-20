terraform {
  required_version = "~> 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }

  # Bucket comes from `-backend-config=bucket=...` (the Makefile), so the account ID is never in code.
  backend "s3" {
    key          = "foundation/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

locals {
  tags = {
    project            = "runway"
    lab                = "00"
    "runway:ephemeral" = "false"
    "runway:stack"     = "foundation"
  }
}

provider "aws" {
  region = "us-west-2"
  default_tags {
    tags = local.tags
  }
}

# Root console sign-ins are recorded in us-east-1, so the alert lives there.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = local.tags
  }
}
