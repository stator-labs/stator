# Moved here from the Lab 00 stack together with the budgets (see budgets.tf).

# AWS allows one "AWS services" monitor per account and creates it itself (Default-Services-Monitor),
# so a second one is refused ("Limit exceeded on dimensional spend monitor creation").
# This monitor is ours instead: it watches the whole account. See the Lab 00 README, Decisions.
resource "aws_ce_anomaly_monitor" "account" {
  name         = "runway-account"
  monitor_type = "CUSTOM"
  # Every key of the Expression object is spelled out (null when unused), ProductAttributes included:
  # the API returns all 7, and leaving one out forces a replacement on every plan.
  monitor_specification = jsonencode({
    And            = null
    CostCategories = null
    Dimensions = {
      Key          = "LINKED_ACCOUNT"
      MatchOptions = null
      Values       = [local.account_id]
    }
    Not               = null
    Or                = null
    ProductAttributes = null
    Tags              = null
  })
}

# AWS allows IMMEDIATE frequency only for SNS subscribers; email gets DAILY or WEEKLY.
# DAILY is the fastest email option. See "Why not an immediate anomaly alert?" in the Lab 00 README.
resource "aws_ce_anomaly_subscription" "email" {
  name             = "runway-anomaly-email"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.account.arn]

  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["1"]
    }
  }
}
