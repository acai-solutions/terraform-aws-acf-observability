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
