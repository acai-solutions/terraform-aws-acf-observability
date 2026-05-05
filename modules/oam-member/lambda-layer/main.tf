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
  bundled_inline_files_dir = "${path.module}/lambda-layer-inline-files"
  bundled_inline_files = {
    for relative_path in fileset(local.bundled_inline_files_dir, "**/*") :
    relative_path => file("${local.bundled_inline_files_dir}/${relative_path}")
  }

  inline_files = merge(local.bundled_inline_files, var.layer_settings.inline_files)

  layer_matrix = {
    for pair in setproduct(var.layer_settings.runtimes, var.layer_settings.architectures) :
    "${replace(pair[0], ".", "")}-${pair[1]}" => {
      runtime = pair[0]
      arch    = pair[1]
    }
  }

  layer_ssm_parameter_prefix = "/${trim(coalesce(var.layer_settings.ssm_parameter_prefix, "platform"), "/")}/lambda-layers/${var.layer_settings.layer_base_name}"
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
    # Hardcoded: this wrapper builds a fixed-purpose "platform logging" layer, not a generic one.
    # Only modules that are actually vendored under modules-external/acai-powertools/lib/acai/
    # may be listed here — anything else triggers "Skipping missing module" warnings at build time.
    acai_modules             = ["logging"]
    pip_requirements         = ["aws-lambda-powertools==2.43.1"]
    inline_files             = local.inline_files
  }

  regions = var.regions

  resource_tags = var.resource_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ SSM PARAMETERS — publish each variant's layer ARN in every region
#
# Delegated to a per-variant child module on purpose; see `ssm_parameter/main.tf` for the rationale.
# ---------------------------------------------------------------------------------------------------------------------
module "layer_ssm" {
  source   = "./ssm_parameter"
  for_each = local.layer_matrix

  variant              = each.key
  layer_base_name      = var.layer_settings.layer_base_name
  ssm_parameter_prefix = local.layer_ssm_parameter_prefix
  regions              = var.regions
  layer_arns           = module.layer[each.key].layer_arns
  resource_tags        = var.resource_tags
}
