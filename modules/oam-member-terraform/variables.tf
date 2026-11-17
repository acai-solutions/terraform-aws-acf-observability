variable "settings" {
  description = "Module Settings"
  type = object({
    aws_regions = object({
      primary   = string
      secondary = list(string)
    })
    oam = optional(object({
      sink_identifiers = map(string)
      resource_types   = optional(list(string), ["AWS::CloudWatch::Metric", "AWS::Logs::LogGroup", "AWS::XRay::Trace"])
      log_group_filter = optional(string, null)
      metric_filter    = optional(string, null)
      # Set or change this value to recreate the OAM links once (e.g. to drop a link_configuration:
      # UpdateLink cannot remove it in place). Keep the value afterwards - removing it recreates them again.
      link_replace_trigger = optional(string, null)
    }), null)
    lambda_layer = optional(object({
      layer_base_name      = string
      runtimes             = list(string)
      architectures        = list(string)
      inline_files         = optional(map(string), {})
      ssm_parameter_prefix = optional(string, null)
    }), null)
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ COMMON
# ---------------------------------------------------------------------------------------------------------------------
variable "resource_tags" {
  description = "A map of tags to assign to the resources in this module."
  type        = map(string)
  default     = {}
}
