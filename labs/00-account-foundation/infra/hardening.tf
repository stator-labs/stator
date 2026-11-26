# Free account-level controls for the labs account (STAT-54). None of them run anything or
# bill anything: they change account defaults so a lab cannot leak data by accident.
#
# Regional settings apply in both regions the guardrail SCP allows. Provider v6 sets the
# region per resource, so one provider block (and one set of default tags) covers both.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  # Must match allowed_regions in platform/infra/foundation (the guardrail SCP).
  regions = toset(["us-west-2", "us-east-1"])
}

# Account-wide, all regions: no bucket or access point can be made public, whatever its policy says.
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# New EBS volumes and snapshot copies are encrypted with the AWS-managed aws/ebs key (no key fee).
resource "aws_ebs_encryption_by_default" "this" {
  for_each = local.regions
  region   = each.key
  enabled  = true
}

# New instances require IMDSv2 tokens unless the AMI or launch request says otherwise.
# Hop limit 2 lets containers on the instance (Lab 03 nodes) still reach the metadata service.
resource "aws_ec2_instance_metadata_defaults" "this" {
  for_each                    = local.regions
  region                      = each.key
  http_tokens                 = "required"
  http_put_response_hop_limit = 2
}

resource "aws_ebs_snapshot_block_public_access" "this" {
  for_each = local.regions
  region   = each.key
  state    = "block-all-sharing"
}

# "block-new-sharing" is the only state AWS offers: existing public AMIs (there are none) stay public.
resource "aws_ec2_image_block_public_access" "this" {
  for_each = local.regions
  region   = each.key
  state    = "block-new-sharing"
}

resource "aws_ssm_service_setting" "no_public_documents" {
  for_each      = local.regions
  region        = each.key
  setting_id    = "arn:${data.aws_partition.current.partition}:ssm:${each.key}:${data.aws_caller_identity.current.account_id}:servicesetting/ssm/documents/console/public-sharing-permission"
  setting_value = "Disable"
}
