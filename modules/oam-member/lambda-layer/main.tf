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
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  inline_files_dir = "${path.module}/lambda-layer-inline-files"
  inline_files = {
    for relative_path in fileset(local.inline_files_dir, "**/*") :
    relative_path => file("${local.inline_files_dir}/${relative_path}")
  }

  layer_matrix = {
    for pair in setproduct(var.layer_settings.layer_runtimes, var.layer_settings.layer_architectures) :
    "${replace(pair[0], ".", "")}-${pair[1]}" => {
      runtime = pair[0]
      arch    = pair[1]
    }
  }

  layer_ssm_parameter_prefix = "/${trim(coalesce(var.layer_settings.ssm_parameter_prefix, "platform"), "/")}/lambda-layers/${var.layer_settings.layer_base_name}"

  layer_ssm_parameters = {
    for pair in setproduct(keys(local.layer_matrix), var.regions) :
    "${pair[0]}/${pair[1]}" => {
      variant = pair[0]
      region  = pair[1]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LAYER — one module call per (runtime, architecture) variant
# ---------------------------------------------------------------------------------------------------------------------
module "layer" {
  source   = "../../../modules-external/acai-powertools/use-cases/terraform-aws-lambda-layer"
  for_each = local.layer_matrix

  layer_settings = {
    layer_name               = "${var.layer_settings.layer_base_name}-${each.key}"
    description              = "Powertools Lambda layer (${each.value.runtime} / ${each.value.arch})"
    compatible_runtimes      = [each.value.runtime]
    compatible_architectures = [each.value.arch]
    acai_modules             = ["logging", "boto3_helper", "python_helper", "storage"]
    pip_requirements         = ["aws-lambda-powertools==2.43.1"]
    inline_files             = local.inline_files
  }

  regions = var.regions

  resource_tags = var.resource_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ SSM PARAMETERS — publish each variant's layer ARN in every region
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ssm_parameter" "layer_arn" {
  #checkov:skip=CKV2_AWS_34: Encryption not required for Lambda layer ARN values
  for_each = local.layer_ssm_parameters

  region      = each.value.region
  name        = "${local.layer_ssm_parameter_prefix}/${each.value.variant}/arn"
  description = "ARN of the powertools Lambda layer '${var.layer_settings.layer_base_name}-${each.value.variant}' in ${each.value.region}."
  type        = "String"
  tier        = "Standard"
  value       = module.layer[each.value.variant].layer_arns[each.value.region]

  tags = var.resource_tags
}
