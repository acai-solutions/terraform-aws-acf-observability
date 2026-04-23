variable "settings" {
  description = "Module Settings"
  type = object({
    aws_regions = object({
      primary   = string
      secondary = list(string)
    })
    oam = object({
      sink_identifiers = map(string)
      resource_types   = optional(list(string), ["AWS::CloudWatch::Metric", "AWS::Logs::LogGroup", "AWS::XRay::Trace"])
      log_group_filter = optional(string, null)
      metric_filter    = optional(string, null)
    })
    lambda_layer = optional(object({
      layer_base_name      = string
      layer_runtimes       = list(string)
      layer_architectures  = list(string)
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
