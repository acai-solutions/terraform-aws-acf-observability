# ---------------------------------------------------------------------------------------------------------------------
# ¦ REQUIREMENTS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}
# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  resource_tags = merge(
    var.resource_tags,
    {
      "acf_module_provider" = "ACAI GmbH",
      "acf_module_name"     = "terraform-aws-acf-observability",
      "acf_sub_module_name" = "oam-sink",
      "acf_module_source"   = "github.com/acai-solutions/terraform-aws-acf-observability",
    }
  )

  all_regions = toset(concat(
    [var.settings.aws_regions.primary],
    var.settings.aws_regions.secondary
  ))
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ OAM SINK — one per region
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "oam_sink" {
  statement {
    actions   = ["oam:CreateLink", "oam:UpdateLink"]
    effect    = "Allow"
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = var.settings.oam.trusted_account_ids
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "oam:ResourceTypes"
      values   = ["AWS::CloudWatch::Metric", "AWS::Logs::LogGroup", "AWS::XRay::Trace"]
    }
  }
}

resource "aws_oam_sink" "this" {
  for_each = local.all_regions

  region = each.value
  name   = var.settings.oam.sink_name
  tags   = local.resource_tags
}

resource "aws_oam_sink_policy" "this" {
  for_each = local.all_regions

  region          = each.value
  sink_identifier = aws_oam_sink.this[each.value].arn
  policy          = data.aws_iam_policy_document.oam_sink.json
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CLOUDWATCH DASHBOARD — Lambda Invocations & Errors
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "lambda" {
  dashboard_name = "${var.settings.oam.sink_name}-lambda-overview"

  dashboard_body = var.dashboard_settings != null ? jsonencode(var.dashboard_settings) : local.default_dashboard_body
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CLOUDWATCH LOG INSIGHTS — Saved Queries
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_query_definition" "lambda_errors" {
  name            = "Lambda/Cross-Account Errors"
  log_group_names = ["/aws/lambda"]

  query_string = <<-EOT
    filter @message like /ERROR|Exception|Task timed out/
    | fields @timestamp, @logStream, @log, @message
    | sort @timestamp desc
    | limit 200
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_error_frequency" {
  name            = "Lambda/Error Frequency (5m bins)"
  log_group_names = ["/aws/lambda"]

  query_string = <<-EOT
    filter @message like /ERROR|Exception|Task timed out/
    | stats count(*) as error_count by bin(5m)
    | sort @timestamp desc
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_slow_executions" {
  name            = "Lambda/Slow Executions (>10s)"
  log_group_names = ["/aws/lambda"]

  query_string = <<-EOT
    filter @duration > 10000
    | fields @timestamp, @logStream, @log, @duration, @billedDuration, @memorySize, @maxMemoryUsed
    | sort @duration desc
    | limit 100
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_cold_starts" {
  name            = "Lambda/Cold Starts"
  log_group_names = ["/aws/lambda"]

  query_string = <<-EOT
    filter @type = "REPORT" and @initDuration > 0
    | fields @timestamp, @logStream, @log, @initDuration, @duration, @memorySize, @maxMemoryUsed
    | sort @initDuration desc
    | limit 100
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_timeouts" {
  name            = "Lambda/Timeouts"
  log_group_names = ["/aws/lambda"]

  query_string = <<-EOT
    filter @message like /Task timed out/
    | fields @timestamp, @logStream, @log, @message
    | sort @timestamp desc
    | limit 100
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_memory_usage" {
  name            = "Lambda/Memory Usage (Top Consumers)"
  log_group_names = ["/aws/lambda"]

  query_string = <<-EOT
    filter @type = "REPORT"
    | stats max(@maxMemoryUsed / @memorySize * 100) as max_memory_pct,
            avg(@maxMemoryUsed / @memorySize * 100) as avg_memory_pct
      by @logStream
    | sort max_memory_pct desc
    | limit 50
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_cost_drivers" {
  name            = "Lambda/Cost Drivers (Duration x Memory)"
  log_group_names = ["/aws/lambda"]

  query_string = <<-EOT
    filter @type = "REPORT"
    | stats sum(@billedDuration) as total_billed_ms,
            count(*) as invocation_count,
            avg(@maxMemoryUsed) as avg_memory_used
      by @logStream
    | sort total_billed_ms desc
    | limit 50
  EOT
}
