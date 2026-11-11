# AWS Budget = an ALERTING mechanism, not a spending cap.
# AWS keeps running (and billing) your resources after the budget is
# exceeded; you just receive emails. Billing data also lags by several
# hours, so alerts arrive after the money has been spent.

resource "aws_budgets_budget" "project" {
  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = format("%.2f", var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Optional: count only costs tagged Project=<project>.
  # AWS expects the format "user:<TagKey>$<TagValue>".
  dynamic "cost_filter" {
    for_each = var.budget_filter_by_project_tag ? [1] : []

    content {
      name   = "TagKeyValue"
      values = [format("user:Project$%s", var.project)]
    }
  }

  # One email alert for each ACTUAL-spend threshold (default 50/80/100%).
  dynamic "notification" {
    for_each = toset(var.budget_actual_alert_thresholds)

    content {
      notification_type          = "ACTUAL"
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      subscriber_email_addresses = var.budget_alert_emails
    }
  }

  # Early warning: AWS predicts month-end spend will exceed the threshold.
  notification {
    notification_type          = "FORECASTED"
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.budget_forecast_alert_threshold
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = var.budget_alert_emails
  }
}
