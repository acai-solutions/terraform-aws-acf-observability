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
      "acf_sub_module_name" = "oam-member",
      "acf_module_source"   = "github.com/acai-solutions/terraform-aws-acf-observability",
    }
  )

  all_regions = toset(concat(
    [var.settings.aws_regions.primary],
    var.settings.aws_regions.secondary
  ))
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ OAM LINK — connect this member account to the central sink in every region
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_oam_link" "this" {
  for_each = local.all_regions

  region          = each.value
  sink_identifier = var.settings.oam.sink_identifiers[each.value]
  label_template  = "$AccountName"
  resource_types  = var.settings.oam.resource_types

  dynamic "link_configuration" {
    for_each = var.settings.oam.log_group_filter != null || var.settings.oam.metric_filter != null ? [1] : []
    content {
      dynamic "log_group_configuration" {
        for_each = var.settings.oam.log_group_filter != null ? [var.settings.oam.log_group_filter] : []
        content {
          filter = log_group_configuration.value
        }
      }
      dynamic "metric_configuration" {
        for_each = var.settings.oam.metric_filter != null ? [var.settings.oam.metric_filter] : []
        content {
          filter = metric_configuration.value
        }
      }
    }
  }

  tags = local.resource_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ OPTIONAL LOGGING LAYER — deploy the powertools layer to all regions
# ---------------------------------------------------------------------------------------------------------------------
module "layer" {
  source = "./lambda-layer"
  count  = var.settings.lambda_layer != null ? 1 : 0

  layer_settings = var.settings.lambda_layer
  regions        = tolist(local.all_regions)

  resource_tags = local.resource_tags
}
