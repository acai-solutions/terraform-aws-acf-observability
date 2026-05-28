variable "variant" {
  description = "Variant key (e.g. 'python312-x86_64'). Used in the SSM parameter name."
  type        = string
}

variable "layer_base_name" {
  description = "Base name of the Lambda layer (used in SSM description only)."
  type        = string
}

variable "ssm_parameter_prefix" {
  description = "Fully-qualified SSM parameter prefix (e.g. '/platform/lambda-layers/platform-logging-layer'). The parameter name will be '<prefix>/<variant>/arn'."
  type        = string
}

variable "regions" {
  description = "Regions in which to publish the SSM parameter."
  type        = list(string)
}

variable "layer_arns" {
  description = "Map of region => Lambda layer ARN for this variant."
  type        = map(string)
}

variable "resource_tags" {
  description = "Tags to apply to the SSM parameters."
  type        = map(string)
  default     = {}
}
