# Email on every root console sign-in in the management account. Member accounts have no
# root password (centralized root access), so management is the one place root can sign in.
# The address must confirm the SNS subscription once (AWS sends a link).

resource "aws_sns_topic" "root_sign_in" {
  # checkov:skip=CKV_AWS_26:EventBridge cannot publish to a topic encrypted with the AWS-managed key; a customer key costs $1/month.
  provider = aws.us_east_1
  name     = "runway-root-sign-in"
}

data "aws_iam_policy_document" "root_sign_in_topic" {
  statement {
    sid       = "EventBridgePublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.root_sign_in.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.root_sign_in.arn]
    }
  }
}

resource "aws_sns_topic_policy" "root_sign_in" {
  provider = aws.us_east_1
  arn      = aws_sns_topic.root_sign_in.arn
  policy   = data.aws_iam_policy_document.root_sign_in_topic.json
}

resource "aws_sns_topic_subscription" "root_sign_in" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.root_sign_in.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_event_rule" "root_sign_in" {
  provider    = aws.us_east_1
  name        = "runway-root-sign-in"
  description = "Root user console sign-in."
  event_pattern = jsonencode({
    "detail-type" = ["AWS Console Sign In via CloudTrail"]
    detail        = { userIdentity = { type = ["Root"] } }
  })
}

resource "aws_cloudwatch_event_target" "root_sign_in" {
  provider  = aws.us_east_1
  rule      = aws_cloudwatch_event_rule.root_sign_in.name
  target_id = "email"
  arn       = aws_sns_topic.root_sign_in.arn
}
