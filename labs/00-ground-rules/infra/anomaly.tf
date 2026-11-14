resource "aws_ce_anomaly_monitor" "services" {
  name              = "runway-services"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

# AWS allows IMMEDIATE frequency only for SNS subscribers; email gets DAILY or WEEKLY.
# DAILY is the fastest email option. See "Why not an immediate alert?" in the Lab 00 README.
resource "aws_ce_anomaly_subscription" "email" {
  name             = "runway-anomaly-email"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

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
