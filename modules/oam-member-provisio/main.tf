# ACAI Cloud Foundation (ACF)
# Copyright (C) 2026 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
#
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


# ---------------------------------------------------------------------------------------------------------------------
# ¦ REQUIREMENTS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.7"
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ PACKAGE IDENTIFIER
# ---------------------------------------------------------------------------------------------------------------------
resource "random_uuid" "module_id" {}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ COMPILE PROVISIO PACKAGES
# ---------------------------------------------------------------------------------------------------------------------
locals {
  resource_tags = templatefile("${path.module}/templates/tags.tf.tftpl", {
    map_of_tags = merge(
      var.resource_tags,
      {
        "module_provider" = "ACAI GmbH",
        "module_name"     = "terraform-aws-acf-observability",
        "module_source"   = "github.com/acai-solutions/terraform-aws-acf-observability",
        "module_feature"  = "oam-member",
        "module_version"  = /*inject_version_start*/ "1.2.0" /*inject_version_end*/
      }
    )
  })

  all_regions = sort(distinct(concat(
    [var.provisio_settings.target_regions.primary_region],
    var.provisio_settings.target_regions.secondary_regions
  )))
  tf_module_name = replace(var.provisio_settings.override_module_name == null ? var.provisio_settings.package_name : var.provisio_settings.override_module_name, "-", "_")

  # The OAM sink_identifiers map must contain an entry for every target region.
  sink_identifiers = var.oam_member_settings.oam.sink_identifiers

  # All OAM sinks live in the monitoring account; derive its ID from any sink ARN.
  # OAM sink ARN format: arn:aws:oam:<region>:<account-id>:sink/<uuid>
  monitoring_account_id = split(":", values(local.sink_identifiers)[0])[4]

  package_files = merge(
    var.provisio_settings.import_resources ? ({
      "import.part" = templatefile("${path.module}/templates/import.part.tftpl", {
        tf_module_name = local.tf_module_name
        all_regions    = local.all_regions
      })
      }) : ({
      "import.part" = ""
    }),
    {
      "main.tf" = templatefile("${path.module}/templates/main.tf.tftpl", {
        primary_region        = var.provisio_settings.target_regions.primary_region
        secondary_regions     = var.provisio_settings.target_regions.secondary_regions
        sink_identifiers      = local.sink_identifiers
        resource_types        = var.oam_member_settings.oam.resource_types
        log_group_filter      = var.oam_member_settings.oam.log_group_filter
        metric_filter         = var.oam_member_settings.oam.metric_filter
        monitoring_account_id = local.monitoring_account_id
        resource_tags         = local.resource_tags
      }),
      "requirements.tf" = templatefile("${path.module}/templates/requirements.tf.tftpl", {
        all_regions          = local.all_regions
        terraform_version    = var.provisio_settings.terraform_version,
        provider_aws_version = var.provisio_settings.provider_aws_version,
      })
    }
  )
}
