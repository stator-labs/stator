# Budget kill switch. When the labs account has spent $30 in a month, AWS Budgets attaches the
# deny-new-spend SCP to the labs OU by itself. Billing data is hours old, so this is a backstop:
# the guardrail SCP (guardrails.tf) does the everyday limiting.
#
# This file creates the SCP but attaches it nowhere. Only the budget action attaches it, and
# only a person detaches it (game day, STAT-36). The SCP denies actions that start new spend.
# Deletes, reads and everything else stay allowed, so the reaper and `make nuke` still work
# while it is on. The list is a best effort: a service missing from it keeps spending.

locals {
  kill_switch_budget = "runway-labs-kill-switch"

  deny_new_spend_actions = [
    # Compute
    "ec2:RunInstances", "ec2:StartInstances", "ec2:CreateNatGateway", "ec2:AllocateAddress",
    "ec2:CreateVolume", "ec2:CreateVpcEndpoint", "ec2:CreateTransitGateway", "ec2:CreateVpnConnection",
    "eks:CreateCluster", "eks:CreateNodegroup", "eks:CreateFargateProfile",
    "ecs:RunTask", "ecs:StartTask", "ecs:CreateService",
    "elasticloadbalancing:CreateLoadBalancer",
    # Data
    "rds:CreateDBInstance", "rds:CreateDBCluster", "rds:RestoreDBInstanceFromDBSnapshot",
    "rds:StartDBInstance", "rds:StartDBCluster",
    "elasticache:CreateCacheCluster", "elasticache:CreateReplicationGroup", "elasticache:CreateServerlessCache",
    "redshift:CreateCluster", "redshift-serverless:CreateWorkgroup",
    "es:CreateDomain", "aoss:CreateCollection",
    "kafka:CreateCluster", "kafka:CreateClusterV2",
    "elasticmapreduce:RunJobFlow",
    "elasticfilesystem:CreateFileSystem", "fsx:CreateFileSystem",
    # AI
    "bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream", "bedrock:Converse",
    "bedrock:ConverseStream", "bedrock:CreateProvisionedModelThroughput",
    "sagemaker:CreateEndpoint", "sagemaker:CreateTrainingJob", "sagemaker:CreateProcessingJob",
    "sagemaker:CreateNotebookInstance",
  ]
}

resource "aws_organizations_policy" "deny_new_spend" {
  name        = "runway-labs-deny-new-spend"
  description = "Attached by the labs kill-switch budget action at $30 a month. Denies actions that start new spend."
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyNewSpend"
      Effect   = "Deny"
      Action   = local.deny_new_spend_actions
      Resource = "*"
    }]
  })
}

# Scoped to the labs account, so management costs (cents) cannot trip it.
resource "aws_budgets_budget" "labs_kill_switch" {
  name         = local.kill_switch_budget
  budget_type  = "COST"
  limit_amount = "30"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "LinkedAccount"
    values = [aws_organizations_account.labs.id]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}

# The role AWS Budgets assumes to attach the SCP. Only the Budgets service can assume it, only
# for this budget, and it can attach or detach one SCP on one OU.
resource "aws_iam_role" "kill_switch" {
  name        = "runway-budget-kill-switch"
  path        = "/runway/"
  description = "Assumed by AWS Budgets to attach the deny-new-spend SCP to the labs OU."
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "budgets.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:budgets::${local.account_id}:budget/${local.kill_switch_budget}" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "kill_switch" {
  name = "attach-deny-new-spend"
  role = aws_iam_role.kill_switch.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AttachOneScpToTheLabsOu"
      Effect   = "Allow"
      Action   = ["organizations:AttachPolicy", "organizations:DetachPolicy"]
      Resource = [aws_organizations_policy.deny_new_spend.arn, aws_organizations_organizational_unit.labs.arn]
    }]
  })
}

resource "aws_budgets_budget_action" "kill_switch" {
  budget_name        = aws_budgets_budget.labs_kill_switch.name
  action_type        = "APPLY_SCP_POLICY"
  approval_model     = "AUTOMATIC"
  notification_type  = "ACTUAL"
  execution_role_arn = aws_iam_role.kill_switch.arn

  action_threshold {
    action_threshold_type  = "PERCENTAGE"
    action_threshold_value = 100
  }

  definition {
    scp_action_definition {
      policy_id  = aws_organizations_policy.deny_new_spend.id
      target_ids = [aws_organizations_organizational_unit.labs.id]
    }
  }

  subscriber {
    address           = var.alert_email
    subscription_type = "EMAIL"
  }

  depends_on = [aws_iam_role_policy.kill_switch]
}
