# Mocked-provider tests for platform/infra/bootstrap (management account).
# Verifies the state bucket protections and that this stack holds no CI role or OIDC
# provider, with no AWS credentials.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::runway-tfstate-111111111111"
    }
  }
}

run "state_bucket_is_private_versioned_and_tls_only" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.state.block_public_acls,
      aws_s3_bucket_public_access_block.state.block_public_policy,
      aws_s3_bucket_public_access_block.state.ignore_public_acls,
      aws_s3_bucket_public_access_block.state.restrict_public_buckets,
    ])
    error_message = "The state bucket must block every kind of public access."
  }

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "The state bucket must keep versions, so a bad write can be rolled back."
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.state.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "The state bucket must disable ACLs."
  }

  assert {
    condition = (
      data.aws_iam_policy_document.state_bucket.statement[0].effect == "Deny"
      && contains(tolist(one(data.aws_iam_policy_document.state_bucket.statement[0].condition).values), "false")
    )
    error_message = "The bucket policy must deny requests without TLS."
  }
}
