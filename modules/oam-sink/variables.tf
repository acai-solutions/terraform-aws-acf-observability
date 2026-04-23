variable "settings" {
  description = "Module Settings"
  type = object({
    aws_regions = object({
      primary   = string
      secondary = list(string)
    })
    oam = object({
      sink_name           = string
      trusted_account_ids = list(string)
    })
  })
}

variable "dashboard_settings" {
  description = "Dashboard Settings"
  type    = any
  default = null
}

variable "resource_tags" {
  description = "A map of tags to assign to the resources in this module."
  type        = map(string)
  default     = {}
}
