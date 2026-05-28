# ACAI Cloud Foundation (ACF)
# Copyright (C) 2026 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
#
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


variable "provisio_settings" {
  description = "ACAI PROVISIO settings"
  type = object({
    package_name         = optional(string, "aws-oam-member")
    override_module_name = optional(string, null)
    terraform_version    = optional(string, ">= 1.5.7")
    provider_aws_version = optional(string, ">= 6.0")
    target_regions = object({
      primary_region    = string
      secondary_regions = list(string)
    })
    import_resources = optional(bool, false)
  })
  validation {
    condition     = !contains(var.provisio_settings.target_regions.secondary_regions, var.provisio_settings.target_regions.primary_region)
    error_message = "The primary region must not be included in the secondary regions."
  }
}

variable "oam_member_settings" {
  description = "Specification of the OAM member resources"
  type = object({
    oam = object({
      # Map of region -> sink_identifier (ARN of the OAM sink in the monitoring account).
      # Must contain an entry for every region listed in provisio_settings.target_regions.
      sink_identifiers = map(string)
      resource_types   = optional(list(string), ["AWS::CloudWatch::Metric", "AWS::Logs::LogGroup", "AWS::XRay::Trace"])
      log_group_filter = optional(string, null)
      metric_filter    = optional(string, null)
    })
  })
  validation {
    condition     = length(var.oam_member_settings.oam.sink_identifiers) > 0
    error_message = "At least one sink_identifier must be provided."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ COMMON
# ---------------------------------------------------------------------------------------------------------------------
variable "resource_tags" {
  description = "A map of tags to assign to the resources in this module."
  type        = map(string)
  default     = {}
}
