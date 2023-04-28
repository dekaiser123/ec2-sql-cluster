locals {
  sns_name = lower(join("-", [var.resource_prefix, var.env, "sql-ec2-alerts-sns"]))
}

resource "aws_sns_topic" "ec2-alerts" {
  name                             = local.sns_name

  tags = merge(
    tomap({ "Name" = local.sns_name }),
    var.tags,
  )
}

resource "aws_sns_topic_subscription" "email" {
  count     = length(var.sns_subscription_email)
  topic_arn = aws_sns_topic.ec2-alerts.arn
  protocol  = "email"
  endpoint  = var.sns_subscription_email[count.index]
}