variable "layer_settings" {
  description = "Settings for the Lambda layer."
  type = object({
    layer_base_name      = string
    layer_runtimes       = list(string)
    layer_architectures  = list(string)
    ssm_parameter_prefix = optional(string, null)
  })
}

variable "regions" {
  description = "List of AWS regions to deploy the layer to."
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ COMMON
# ---------------------------------------------------------------------------------------------------------------------


variable "resource_tags" {
  description = "A map of tags to assign to the resources in this module."
  type        = map(string)
  default     = {}
}
