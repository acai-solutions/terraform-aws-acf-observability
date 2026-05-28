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
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_organizations_organization" "current" {}


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

  # Trust the whole AWS Organization on the sink resource policy when explicitly requested.
  # trusted_account_ids is independent: it always drives the drill-down dashboard's account selector,
  # even when org-wide trust is enabled (e.g. to highlight "core" accounts).
  trust_whole_org = var.settings.oam.allow_full_organization
}

data "aws_organizations_organization" "this" {
  count = local.trust_whole_org ? 1 : 0
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DISCOVER LAMBDA LOG GROUPS (sink account, primary region)
# ¦ Used by the "By Region" log-Insights dashboard widgets.
# ¦ Note: Cross-account log groups from OAM source accounts are NOT discovered here.
# ---------------------------------------------------------------------------------------------------------------------
data "aws_cloudwatch_log_groups" "lambda" {
  log_group_name_prefix = "/aws/lambda/"
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
      identifiers = local.trust_whole_org ? ["*"] : var.settings.oam.trusted_account_ids
    }

    dynamic "condition" {
      for_each = local.trust_whole_org ? [1] : []
      content {
        test     = "StringEquals"
        variable = "aws:PrincipalOrgID"
        values   = [data.aws_organizations_organization.this[0].id]
      }
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
# ¦ CLOUDWATCH CROSS-ACCOUNT — MONITORING-ACCOUNT SERVICE ROLE
# ¦ Assumed by the CloudWatch service in this (monitoring) account to call the
# ¦ CloudWatch-CrossAccountSharing* roles in every source account in the org.
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "cw_cross_account_v2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudwatch-crossaccount.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudwatch:*:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

data "aws_iam_policy_document" "cw_cross_account_v2" {
  statement {
    sid       = "AssumeCrossAccountSharingRoles"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::*:role/CloudWatch-CrossAccountSharing*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceOrgId"
      values   = [data.aws_organizations_organization.current.id]
    }
  }
}

resource "aws_iam_role" "cw_cross_account_v2" {
  count = var.create_cw_cross_account_v2_role ? 1 : 0

  name               = "ServiceRoleForCloudWatchCrossAccountV2"
  path               = "/service-role/"
  description        = "Allows CloudWatch to assume CloudWatch-CrossAccountSharing roles in remote accounts on behalf of the current account in order to display data cross-account, cross region"
  assume_role_policy = data.aws_iam_policy_document.cw_cross_account_v2_trust.json
  tags               = local.resource_tags
}

resource "aws_iam_role_policy" "cw_cross_account_v2" {
  count = var.create_cw_cross_account_v2_role ? 1 : 0

  name   = "CloudWatchCrossAccountAccess-Organization"
  role   = aws_iam_role.cw_cross_account_v2[0].name
  policy = data.aws_iam_policy_document.cw_cross_account_v2.json
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CLOUDWATCH DASHBOARDS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "lambda_overview" {
  dashboard_name = "${var.settings.oam.sink_name}-lambda-overview"

  dashboard_body = var.dashboard_settings != null ? jsonencode(var.dashboard_settings) : local.global_dashboard_body
}

resource "aws_cloudwatch_dashboard" "lambda_drilldown" {
  count = length(local.trusted_account_ids_unique) > 0 ? 1 : 0

  dashboard_name = "${var.settings.oam.sink_name}-lambda-drilldown"

  dashboard_body = local.drilldown_dashboard_body
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CLOUDWATCH LOG INSIGHTS — Saved Queries
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_query_definition" "lambda_errors" {
  name = "Lambda/Cross-Account Errors"

  query_string = <<-EOT
    SOURCE logGroups(namePrefix: ["/aws/lambda/"])
    | filter @message like /ERROR|Exception|Task timed out/
    | fields @timestamp, @logStream, @log, @message
    | sort @timestamp desc
    | limit 200
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_error_frequency" {
  name = "Lambda/Error Frequency (5m bins)"

  query_string = <<-EOT
    SOURCE logGroups(namePrefix: ["/aws/lambda/"])
    | filter @message like /ERROR|Exception|Task timed out/
    | stats count(*) as error_count by bin(5m)
    | sort @timestamp desc
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_slow_executions" {
  name = "Lambda/Slow Executions (>10s)"

  query_string = <<-EOT
    SOURCE logGroups(namePrefix: ["/aws/lambda/"])
    | filter @duration > 10000
    | fields @timestamp, @logStream, @log, @duration, @billedDuration, @memorySize, @maxMemoryUsed
    | sort @duration desc
    | limit 100
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_cold_starts" {
  name = "Lambda/Cold Starts"

  query_string = <<-EOT
    SOURCE logGroups(namePrefix: ["/aws/lambda/"])
    | filter @type = "REPORT" and @initDuration > 0
    | fields @timestamp, @logStream, @log, @initDuration, @duration, @memorySize, @maxMemoryUsed
    | sort @initDuration desc
    | limit 100
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_timeouts" {
  name = "Lambda/Timeouts"

  query_string = <<-EOT
    SOURCE logGroups(namePrefix: ["/aws/lambda/"])
    | filter @message like /Task timed out/
    | fields @timestamp, @logStream, @log, @message
    | sort @timestamp desc
    | limit 100
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_memory_usage" {
  name = "Lambda/Memory Usage (Top Consumers)"

  query_string = <<-EOT
    SOURCE logGroups(namePrefix: ["/aws/lambda/"])
    | filter @type = "REPORT"
    | stats max(@maxMemoryUsed / @memorySize * 100) as max_memory_pct,
            avg(@maxMemoryUsed / @memorySize * 100) as avg_memory_pct
      by @logStream
    | sort max_memory_pct desc
    | limit 50
  EOT
}

resource "aws_cloudwatch_query_definition" "lambda_cost_drivers" {
  name = "Lambda/Cost Drivers (Duration x Memory)"

  query_string = <<-EOT
    SOURCE logGroups(namePrefix: ["/aws/lambda/"])
    | filter @type = "REPORT"
    | stats sum(@billedDuration) as total_billed_ms,
            count(*) as invocation_count,
            avg(@maxMemoryUsed) as avg_memory_used
      by @logStream
    | sort total_billed_ms desc
    | limit 50
  EOT
}
