variable "layer_settings" {
  description = "Settings for the Lambda layer."
  type = object({
    layer_base_name      = string
    runtimes             = list(string)
    architectures        = list(string)
    inline_files         = optional(map(string), {})
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
