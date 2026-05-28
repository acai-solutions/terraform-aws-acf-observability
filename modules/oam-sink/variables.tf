variable "settings" {

  description = "Module Settings"
  type = object({
    aws_regions = object({
      primary   = string
      secondary = list(string)
    })
    oam = optional(object({
      sink_name               = optional(string, "platform-observability-sink")
      trusted_account_ids     = optional(list(string), [])
      allow_full_organization = optional(bool, false)
    }), {})
  })

  validation {
    condition     = var.settings.oam.allow_full_organization || length(var.settings.oam.trusted_account_ids) > 0
    error_message = "settings.oam: provide trusted_account_ids or set allow_full_organization = true."
  }
}

variable "dashboard_settings" {
  description = "Dashboard Settings"
  type        = any
  default     = null
}

variable "create_cw_cross_account_v2_role" {
  description = "Whether to create the ServiceRoleForCloudWatchCrossAccountV2 IAM role and its inline policy. Set to false if the role already exists (for example, because it was auto-created by the CloudWatch console cross-account observability wizard) to avoid an EntityAlreadyExists conflict."
  type        = bool
  default     = true
}

variable "resource_tags" {
  description = "A map of tags to assign to the resources in this module."
  type        = map(string)
  default     = {}
}
