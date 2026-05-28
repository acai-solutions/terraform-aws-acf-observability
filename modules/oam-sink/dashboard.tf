# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  all_regions_list = concat(
    [var.settings.aws_regions.primary],
    var.settings.aws_regions.secondary
  )

  # Dedupe + sort trusted_account_ids — CloudWatch dashboard variables reject duplicate values,
  # and sorting gives a stable, predictable order in the Account selector dropdown.
  trusted_account_ids_unique = sort(distinct(var.settings.oam.trusted_account_ids))

  # ============================================================================================
  # DASHBOARD 1: Global Overview (no interactive filters — shows all accounts/regions at once)
  # ============================================================================================
  global_dashboard_body = jsonencode({
    widgets = concat(
      # --- Row 0: By Account ---
      [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 8
          height = 12
          properties = {
            title   = "Lambda Invocations by Account"
            view    = "timeSeries"
            stacked = false
            region  = var.settings.aws_regions.primary
            metrics = [
              for account_id in local.trusted_account_ids_unique :
              ["AWS/Lambda", "Invocations", { stat = "Sum", period = 300, accountId = account_id, label = account_id }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 0
          width  = 8
          height = 12
          properties = {
            title   = "Lambda Errors by Account"
            view    = "timeSeries"
            stacked = false
            region  = var.settings.aws_regions.primary
            metrics = [
              for account_id in local.trusted_account_ids_unique :
              ["AWS/Lambda", "Errors", { stat = "Sum", period = 300, accountId = account_id, label = account_id }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 0
          width  = 8
          height = 12
          properties = {
            title   = "Lambda Duration p95 by Account"
            view    = "timeSeries"
            stacked = false
            region  = var.settings.aws_regions.primary
            metrics = [
              for account_id in local.trusted_account_ids_unique :
              ["AWS/Lambda", "Duration", { stat = "p95", period = 300, accountId = account_id, label = account_id }]
            ]
          }
        }
      ],
      # --- Row 1: By Region (log-based) ---
      length(data.aws_cloudwatch_log_groups.lambda.log_group_names) > 0 ? [
        {
          type   = "log"
          x      = 0
          y      = 12
          width  = 12
          height = 12
          properties = {
            title         = "Log Errors by Region"
            query         = "fields @timestamp, aws_region\n| filter tolower(level) = \"error\" or @message like /ERROR/\n| stats count(*) as error_count by aws_region\n| sort error_count desc"
            region        = var.settings.aws_regions.primary
            logGroupNames = data.aws_cloudwatch_log_groups.lambda.log_group_names
            view          = "table"
          }
        },
        {
          type   = "log"
          x      = 12
          y      = 12
          width  = 12
          height = 12
          properties = {
            title         = "Log Invocations by Region (5m bins)"
            query         = "fields @timestamp, aws_region\n| stats count(*) as invocations by aws_region, bin(5m)\n| sort invocations desc"
            region        = var.settings.aws_regions.primary
            logGroupNames = data.aws_cloudwatch_log_groups.lambda.log_group_names
            view          = "timeSeries"
          }
        }
      ] : [],
      # --- Row 2: By Function Name ---
      [
        {
          type   = "metric"
          x      = 0
          y      = 24
          width  = 8
          height = 12
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
          x      = 8
          y      = 24
          width  = 8
          height = 12
          properties = {
            title   = "Lambda Errors by Function"
            view    = "timeSeries"
            stacked = false
            region  = var.settings.aws_regions.primary
            metrics = [
              [{ expression = "SEARCH('{AWS/Lambda,FunctionName} MetricName=\"Errors\"', 'Sum', 300)", id = "errors" }]
            ]
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 24
          width  = 8
          height = 12
          properties = {
            title   = "Lambda Duration p95 by Function"
            view    = "timeSeries"
            stacked = false
            region  = var.settings.aws_regions.primary
            metrics = [
              [{ expression = "SEARCH('{AWS/Lambda,FunctionName} MetricName=\"Duration\"', 'p95', 300)", id = "duration" }]
            ]
          }
        }
      ]
    )
  })

  # ============================================================================================
  # DASHBOARD 2: Drill-Down (Account + Region selectors)
  # ============================================================================================
  drilldown_dashboard_body = jsonencode({
    variables = [
      {
        type         = "pattern"
        pattern      = "__ACCOUNT_ID__"
        inputType    = "select"
        id           = "accountId"
        label        = "Account"
        defaultValue = try(local.trusted_account_ids_unique[0], "")
        visible      = true
        values = [
          for a in local.trusted_account_ids_unique : { value = a, label = a }
        ]
      },
      {
        type         = "pattern"
        pattern      = "__REGION__"
        inputType    = "select"
        id           = "region"
        label        = "Region"
        defaultValue = var.settings.aws_regions.primary
        visible      = true
        values = [
          for r in local.all_regions_list : { value = r, label = r }
        ]
      }
    ]
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "## Account drill-down — use the **Account** and **Region** selectors at the top to filter"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 12
        properties = {
          title   = "Invocations (selected account)"
          view    = "timeSeries"
          stacked = false
          region  = "__REGION__"
          metrics = [
            [{ expression = "SEARCH('{AWS/Lambda,FunctionName} MetricName=\"Invocations\" :aws.AccountId=\"__ACCOUNT_ID__\"', 'Sum', 300)", id = "inv_total" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 12
        properties = {
          title   = "Errors (selected account)"
          view    = "timeSeries"
          stacked = false
          region  = "__REGION__"
          metrics = [
            [{ expression = "SEARCH('{AWS/Lambda,FunctionName} MetricName=\"Errors\" :aws.AccountId=\"__ACCOUNT_ID__\"', 'Sum', 300)", id = "err_total" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 12
        properties = {
          title   = "Duration p95 (selected account)"
          view    = "timeSeries"
          stacked = false
          region  = "__REGION__"
          metrics = [
            [{ expression = "SEARCH('{AWS/Lambda,FunctionName} MetricName=\"Duration\" :aws.AccountId=\"__ACCOUNT_ID__\"', 'p95', 300)", id = "dur_total" }]
          ]
        }
      }
    ]
  })
}

