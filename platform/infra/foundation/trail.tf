# One organization trail: management events from every account, all regions, kept 90 days.
# The first copy of management events is free; S3 storage is cents a month.

locals {
  trail_name   = "runway-org-trail"
  trail_arn    = "arn:aws:cloudtrail:us-west-2:${local.account_id}:trail/${local.trail_name}"
  trail_bucket = "runway-org-trail-${local.account_id}"
}

resource "aws_s3_bucket" "trail" {
  # checkov:skip=CKV_AWS_18:Access logging needs a second bucket. The trail itself is the audit record.
  # checkov:skip=CKV_AWS_144:Cross-region replication doubles storage for 90-day logs.
  # checkov:skip=CKV_AWS_145:SSE-S3 instead of KMS: a customer-managed key costs $1/month, which breaks $0 idle.
  # checkov:skip=CKV2_AWS_62:No consumer for event notifications.
  bucket = local.trail_bucket

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.trail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id

  rule {
    id     = "expire-after-90-days"
    status = "Enabled"
    filter {}
    expiration {
      days = 90
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid       = "CloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid     = "CloudTrailWrite"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.trail.arn}/AWSLogs/${local.account_id}/*",
      "${aws_s3_bucket.trail.arn}/AWSLogs/${var.organization_id}/*",
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.trail.arn, "${aws_s3_bucket.trail.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = data.aws_iam_policy_document.trail_bucket.json
}

resource "aws_cloudtrail" "org" {
  # checkov:skip=CKV_AWS_35:SSE-S3 on the bucket instead of a $1/month KMS key.
  # checkov:skip=CKV_AWS_252:No SNS topic per log file; the root sign-in alert covers the urgent case.
  # checkov:skip=CKV2_AWS_10:CloudWatch Logs delivery costs per GB; S3 is enough to investigate.
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.trail.id
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.trail, aws_organizations_organization.this]
}
