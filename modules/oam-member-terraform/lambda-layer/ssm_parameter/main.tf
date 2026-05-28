# ---------------------------------------------------------------------------------------------------------------------
# ¦ REQUIREMENTS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ SSM PARAMETERS — publish this variant's layer ARN in every region
#
# Why this is a separate child module (instead of one `aws_ssm_parameter` block in the parent with a
# composite "variant/region" key):
#
# Terraform builds dependency edges at the resource-node level, not per-instance. A single
# `aws_ssm_parameter` resource depending on the parent's `module.layer` (`for_each` over variants)
# creates one edge from the SSM node to the layer node spanning ALL variants. With
# `create_before_destroy` on the inner `aws_lambda_layer_version`, mutating the variant set
# (adding/removing a runtime) closes a graph cycle through the SSM resource.
#
# Wrapping the SSM resource in a per-variant child module gives each variant its own self-contained
# subgraph: destroying `module.layer["python310-x86_64"]` only touches `module.layer_ssm["python310-x86_64"]`
# and never crosses to sibling variants.
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ssm_parameter" "layer_arn" {
  #checkov:skip=CKV2_AWS_34: Encryption not required for Lambda layer ARN values
  for_each = toset(var.regions)

  region      = each.key
  name        = "${var.ssm_parameter_prefix}/${var.variant}/arn"
  description = "ARN of the powertools Lambda layer '${var.layer_base_name}-${var.variant}' in ${each.key}."
  type        = "String"
  tier        = "Standard"
  value       = var.layer_arns[each.key]

  tags = var.resource_tags
}
