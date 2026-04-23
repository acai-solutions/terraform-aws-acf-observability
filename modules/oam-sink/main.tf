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

  default_dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Invocations"
          view    = "timeSeries"
          stacked = false
          region  = var.settings.aws_regions.primary
          metrics = [
            for account_id in var.settings.oam.trusted_account_ids :
            ["AWS/Lambda", "Invocations", { stat = "Sum", period = 300, accountId = account_id }]
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
          title   = "Lambda Errors"
          view    = "timeSeries"
          stacked = false
          region  = var.settings.aws_regions.primary
          metrics = [
            for account_id in var.settings.oam.trusted_account_ids :
            ["AWS/Lambda", "Errors", { stat = "Sum", period = 300, accountId = account_id }]
          ]
        }
      }
    ]
  })
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
