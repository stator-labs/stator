# Runs with no AWS access: the provider is mocked. It checks what the code plans, not what AWS accepts.
# The mock invents random strings for computed values, and AWS ARN validation rejects them,
# so the values the code feeds into ARNs are fixed below.
#
# The budget and anomaly tests moved to platform/infra/foundation/tests with the resources.
# The reaper role moved to platform/infra/labs-bootstrap (stator-reaper).

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

run "s3_public_access_is_blocked_account_wide" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_account_public_access_block.this.block_public_acls,
      aws_s3_account_public_access_block.this.ignore_public_acls,
      aws_s3_account_public_access_block.this.block_public_policy,
      aws_s3_account_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "All four S3 account Block Public Access settings must be on."
  }
}

run "regional_controls_cover_both_allowed_regions" {
  command = plan

  assert {
    condition = alltrue([
      for r in ["us-west-2", "us-east-1"] : alltrue([
        aws_ebs_encryption_by_default.this[r].enabled,
        aws_ec2_instance_metadata_defaults.this[r].http_tokens == "required",
        aws_ebs_snapshot_block_public_access.this[r].state == "block-all-sharing",
        aws_ec2_image_block_public_access.this[r].state == "block-new-sharing",
        aws_ssm_service_setting.no_public_documents[r].setting_value == "Disable",
      ])
    ])
    error_message = "Every regional control must be set in us-west-2 and us-east-1."
  }

  assert {
    condition     = length(aws_ebs_encryption_by_default.this) == 2
    error_message = "Regional controls must cover exactly the two regions the guardrail SCP allows."
  }

  assert {
    condition     = endswith(aws_ssm_service_setting.no_public_documents["us-east-1"].setting_id, ":us-east-1:111111111111:servicesetting/ssm/documents/console/public-sharing-permission")
    error_message = "The SSM setting ARN must name its own region and the account."
  }
}

run "imds_hop_limit_leaves_room_for_containers" {
  command = plan

  assert {
    condition     = alltrue([for m in aws_ec2_instance_metadata_defaults.this : m.http_put_response_hop_limit == 2])
    error_message = "IMDS hop limit must be 2 so containers on a node can reach metadata."
  }
}
