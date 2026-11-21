# Runs with no AWS access: the provider is mocked. It checks what the code plans, not what AWS accepts.
# The mock invents random strings for computed values, and AWS ARN validation rejects them,
# so the values the code feeds into ARNs are fixed below.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
  mock_resource "aws_ce_anomaly_monitor" {
    defaults = { arn = "arn:aws:ce::111111111111:anomalymonitor/mock" }
  }
}

variables {
  alert_email       = "alerts@example.com"
  github_sub_prefix = "repo:owner@1/repo@2"
}

run "budgets_at_5_15_and_30" {
  command = plan

  assert {
    condition     = toset(keys(aws_budgets_budget.monthly)) == toset(["5", "15", "30"])
    error_message = "Expected budgets at $5, $15 and $30."
  }

  assert {
    condition     = alltrue([for b in aws_budgets_budget.monthly : b.limit_unit == "USD" && b.time_unit == "MONTHLY"])
    error_message = "Every budget must be monthly, in USD."
  }
}

run "only_the_top_budget_warns_on_forecast" {
  command = plan

  assert {
    condition     = length(aws_budgets_budget.monthly["5"].notification) == 1 && length(aws_budgets_budget.monthly["15"].notification) == 1
    error_message = "The $5 and $15 budgets must have the actual-spend notification only."
  }

  assert {
    condition     = length(aws_budgets_budget.monthly["30"].notification) == 2
    error_message = "The $30 budget must also warn on forecast."
  }
}

run "anomaly_alert_is_daily_email_from_1_dollar" {
  command = plan

  assert {
    condition     = aws_ce_anomaly_subscription.email.frequency == "DAILY"
    error_message = "Email subscribers can only get DAILY or WEEKLY. DAILY is the fastest."
  }

  assert {
    condition     = one(aws_ce_anomaly_subscription.email.threshold_expression[0].dimension[0].values) == "1"
    error_message = "The anomaly threshold must stay at $1."
  }
}

run "reaper_role_is_bounded" {
  command = plan

  assert {
    condition     = aws_iam_role.reaper.path == "/runway/" && aws_iam_role.reaper.max_session_duration == 3600
    error_message = "The reaper role must sit under /runway/ with 1-hour sessions."
  }

  assert {
    condition     = endswith(aws_iam_role.reaper.permissions_boundary, ":policy/runway/runway-boundary")
    error_message = "The reaper role must carry the runway permissions boundary."
  }
}

run "rejects_a_bad_alert_email" {
  command = plan

  variables {
    alert_email = "not-an-email"
  }

  expect_failures = [var.alert_email]
}

run "rejects_a_wildcard_oidc_subject" {
  command = plan

  variables {
    github_sub_prefix = "repo:owner/*"
  }

  expect_failures = [var.github_sub_prefix]
}
