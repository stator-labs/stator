locals {
  # Monthly cost budgets in USD. Only the top one also warns on forecast.
  budgets = {
    5  = { forecast = false }
    15 = { forecast = false }
    30 = { forecast = true }
  }
}

resource "aws_budgets_budget" "monthly" {
  for_each = local.budgets

  name         = "runway-budget-${each.key}"
  budget_type  = "COST"
  limit_amount = tostring(each.key)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  dynamic "notification" {
    for_each = each.value.forecast ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 100
      threshold_type             = "PERCENTAGE"
      notification_type          = "FORECASTED"
      subscriber_email_addresses = [var.alert_email]
    }
  }
}
