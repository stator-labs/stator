# The budgets and the anomaly monitor moved to platform/infra/foundation (STAT-36): the CI roles
# move to the labs account and cannot manage management-account budgets.
#
# These blocks make this stack forget them WITHOUT destroying anything. They stay in AWS and are
# imported into the foundation stack (`make import-budgets` there). Remove this file once both
# steps are done. Never apply foundation before this stack has forgotten them and they are imported.

removed {
  from = aws_budgets_budget.monthly
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_ce_anomaly_monitor.account
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_ce_anomaly_subscription.email
  lifecycle {
    destroy = false
  }
}
