# One SCP on the labs OU. SCPs never apply to the management account or to service-linked roles.
# Deny-list style: AWS's FullAWSAccess policy stays attached and these statements carve out of it.

locals {
  # Global services that answer from us-east-1 whatever region the caller picked.
  global_actions = [
    "account:*", "budgets:*", "ce:*", "cloudfront:*", "health:*", "iam:*", "organizations:*",
    "pricing:*", "route53:*", "route53domains:*", "s3:GetBucketLocation", "s3:ListAllMyBuckets",
    "sso:*", "sts:*", "support:*", "trustedadvisor:*", "waf:*", "wafv2:*",
  ]

  # Reserved capacity and savings plans: a one-click, one-to-three-year commitment.
  commitment_actions = [
    "dynamodb:PurchaseReservedCapacityOfferings", "ec2:AcceptReservedInstancesExchangeQuote",
    "ec2:PurchaseCapacityBlock", "ec2:PurchaseHostReservation", "ec2:PurchaseReservedInstancesOffering",
    "ec2:PurchaseScheduledInstances", "elasticache:PurchaseReservedCacheNodesOffering",
    "es:PurchaseReservedInstanceOffering", "memorydb:PurchaseReservedNodesOffering",
    "rds:PurchaseReservedDBInstancesOffering", "redshift:PurchaseReservedNodeOffering",
    "savingsplans:CreateSavingsPlan",
  ]

  labs_scp = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyOtherRegions"
        Effect    = "Deny"
        NotAction = local.global_actions
        Resource  = "*"
        Condition = { StringNotEquals = { "aws:RequestedRegion" = var.allowed_regions } }
      },
      {
        Sid      = "DenyCommitments"
        Effect   = "Deny"
        Action   = local.commitment_actions
        Resource = "*"
      },
      {
        Sid       = "DenyLargeInstances"
        Effect    = "Deny"
        Action    = "ec2:RunInstances"
        Resource  = "arn:aws:ec2:*:*:instance/*"
        Condition = { StringNotLike = { "ec2:InstanceType" = var.allowed_instance_types } }
      },
      {
        Sid      = "DenyLeavingOrganization"
        Effect   = "Deny"
        Action   = "organizations:LeaveOrganization"
        Resource = "*"
      },
      {
        # IAM role manager would create roles from AWS templates, outside OpenTofu,
        # outside /runway/ and without the permissions boundary.
        Sid       = "DenyRoleManagerEnable"
        Effect    = "Deny"
        Action    = "iam:PutAccountProperties"
        Resource  = "*"
        Condition = { "ForAnyValue:StringEquals" = { "iam:AccountPropertyNamespaces" = "RoleManager" } }
      },
      {
        Sid       = "DenyTemplateRoles"
        Effect    = "Deny"
        Action    = "iam:*"
        Resource  = "*"
        Condition = { Null = { "iam:RoleTemplateARN" = "false" } }
      },
    ]
  }
}

resource "aws_organizations_policy" "labs" {
  name        = "runway-labs-guardrails"
  description = "Regions, commitments, instance types, org exit and role manager for the labs OU."
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(local.labs_scp)
}

resource "aws_organizations_policy_attachment" "labs" {
  policy_id = aws_organizations_policy.labs.id
  target_id = aws_organizations_organizational_unit.labs.id
}
