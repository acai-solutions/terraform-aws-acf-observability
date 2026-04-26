# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  all_regions_list = concat(
    [var.settings.aws_regions.primary],
    var.settings.aws_regions.secondary
  )

  default_dashboard_body = jsonencode({
    widgets = concat(
      # --- Row 0: By Account ---
      [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 12
          height = 6
          properties = {
            title   = "Lambda Invocations by Account"
            view    = "timeSeries"
            stacked = false
            region  = var.settings.aws_regions.primary
            metrics = [
              for account_id in var.settings.oam.trusted_account_ids :
              ["AWS/Lambda", "Invocations", { stat = "Sum", period = 300, accountId = account_id, label = account_id }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 0
          width  = 12
          height = 6
          properties = {
            title   = "Lambda Errors by Account"
            view    = "timeSeries"
            stacked = false
            region  = var.settings.aws_regions.primary
            metrics = [
              for account_id in var.settings.oam.trusted_account_ids :
              ["AWS/Lambda", "Errors", { stat = "Sum", period = 300, accountId = account_id, label = account_id }]
            ]
          }
        }
      ],
      # --- Row 1: By Region ---
      [
        {
          type   = "metric"
          x      = 0
          y      = 6
          width  = 12
          height = 6
          properties = {
            title   = "Lambda Invocations by Region"
            view    = "timeSeries"
            stacked = false
            region  = var.settings.aws_regions.primary
            metrics = [
              for region in local.all_regions_list :
              ["AWS/Lambda", "Invocations", { stat = "Sum", period = 300, region = region, label = region }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 6
          width  = 12
          height = 6
          properties = {
            title   = "Lambda Errors by Region"
            view    = "timeSeries"
            stacked = false
            region  = var.settings.aws_regions.primary
            metrics = [
              for region in local.all_regions_list :
              ["AWS/Lambda", "Errors", { stat = "Sum", period = 300, region = region, label = region }]
            ]
          }
        }
      ],
      # --- Row 2: By Function Name ---
      [
        {
          type   = "metric"
          x      = 0
          y      = 12
          width  = 12
          height = 6
          properties = {
            title   = "Lambda Invocations by Function"
            view    = "timeSeries"
            stacked = false
            region  = var.settings.aws_regions.primary
            metrics = [
              [{ expression = "SEARCH('{AWS/Lambda,FunctionName} MetricName=\"Invocations\"', 'Sum', 300)", id = "invocations" }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 12
          width  = 12
          height = 6
          properties = {
            title   = "Lambda Errors by Function"
            view    = "timeSeries"
            stacked = false
            region  = var.settings.aws_regions.primary
            metrics = [
              [{ expression = "SEARCH('{AWS/Lambda,FunctionName} MetricName=\"Errors\"', 'Sum', 300)", id = "errors" }]
            ]
          }
        }
      ]
    )
  })
}

