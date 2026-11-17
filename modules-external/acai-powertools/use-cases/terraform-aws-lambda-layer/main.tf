# ---------------------------------------------------------------------------------------------------------------------
# ¦ REQUIREMENTS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.3.10"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.0"
      configuration_aliases = []
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3"
    }
    # Still needed to drop the former null_resource.build_layer from existing states.
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ MODULE VERSION
# ---------------------------------------------------------------------------------------------------------------------
locals {
  resource_tags = merge(
    var.resource_tags,
    {
      "product"       = "PowerTools",
      "semper_vendor" = "ACAI GmbH",
    }
  )
  aws_ssm_parameter_prefix = var.ssm_parameter_prefix == "" ? "" : "/${lower(var.ssm_parameter_prefix)}"
  solution_version         = "1.0.10"
}
resource "aws_ssm_parameter" "product_version" {
  # The parameter name is namespaced per consuming module via
  # var.module_context (e.g. /acai/semper/powertools/productversion), so
  # different pipelines (SEMPER, PROVISIO, IDC, account-cache, ...) deploying
  # into the same account no longer fight over one shared parameter.
  # With the default module_context = "" the legacy shared name
  # /acai/powertools/productversion is kept (backward compatible).
  # If the module is instantiated more than once with the same
  # module_context in one workspace, disable the parameter on all but one
  # instance via `create_product_version_ssm_parameter = false`.
  count = var.create_product_version_ssm_parameter ? 1 : 0

  #checkov:skip=CKV2_AWS_34: AWS SSM Parameter should be Encrypted not required for module version
  # Note: this parameter is created in the provider's default region only,
  # even when var.regions is used to publish the layer in multiple regions.
  name           = lower("${local.aws_ssm_parameter_prefix}/acai/${var.module_context}powertools/productversion")
  type           = "String"
  insecure_value = local.solution_version
  overwrite      = true
  tags           = local.resource_tags
}

# Keep existing states (created before the count toggle) without destroy/create of the parameter.
moved {
  from = aws_ssm_parameter.product_version
  to   = aws_ssm_parameter.product_version[0]
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # Per-instance build paths keyed by layer_name — keeps `for_each`
  # invocations from sharing (and racing on) the same directories/zip.
  # Build artefacts live under path.root (the consumer workspace) instead of
  # path.module (which lives inside .terraform/modules/ and gets wiped by
  # `terraform init` in CI apply stages).
  # The build script gets absolute paths (independent of its working directory).
  layer_source_folder       = "${abspath(path.root)}/.layer-build/${var.layer_settings.layer_name}"
  zip_folder                = "${abspath(path.root)}/.layer-build"
  acai_powertools_layer_zip = "${local.zip_folder}/${var.layer_settings.layer_name}.zip"

  # The layer version gets the same file as a path relative to the root module.
  # `filename` forces a new layer version when it changes, so it must not contain
  # the workspace location: an absolute path differs between CI agents
  # (/home/vsts/... vs /home/runner/..., work folder numbers, local runs) and would
  # replace the layer - and update every Lambda using it - without any real change.
  # A saved plan would also carry the plan agent's path to the apply agent.
  layer_zip_filename = "${path.root}/.layer-build/${var.layer_settings.layer_name}.zip"

  is_windows = length(regexall("^[A-Za-z]:[\\\\/]", abspath(path.module))) > 0

  has_acai_modules = length(var.layer_settings.acai_modules) > 0

  # Hash of the acai source tree so layer rebuilds when library code changes.
  acai_source_dir = "${path.module}/../../lib/acai"
  acai_source_hash = local.has_acai_modules ? sha1(join("", [
    for f in fileset(local.acai_source_dir, "**/*.py") :
    filesha1("${local.acai_source_dir}/${f}")
  ])) : ""

  # Derive pip target platform from compatible_architectures
  arch_platform_map = {
    "arm64"  = "manylinux2014_aarch64"
    "x86_64" = "manylinux2014_x86_64"
  }
  pip_platform          = try(local.arch_platform_map[var.layer_settings.compatible_architectures[0]], null)
  runtime_version_parts = try(regex("(\\d+)\\.(\\d+)", var.layer_settings.compatible_runtimes[0]), null)
  pip_python_version    = local.runtime_version_parts != null ? "${local.runtime_version_parts[0]}${local.runtime_version_parts[1]}" : null

  pip_requirements      = var.layer_settings.pip_requirements
  has_pip_requirements  = length(local.pip_requirements) > 0
  pip_requirements_json = local.has_pip_requirements ? jsonencode(local.pip_requirements) : ""
  pip_requirements_hash = local.has_pip_requirements ? md5(local.pip_requirements_json) : ""

  has_inline_files  = length(var.layer_settings.inline_files) > 0
  inline_files_json = local.has_inline_files ? jsonencode(var.layer_settings.inline_files) : ""

  # build_layer.py arguments (as a list: passed through the external data source query as JSON)
  build_args = concat(
    local.has_acai_modules ? concat(["--modules"], var.layer_settings.acai_modules, ["--resolve-deps"]) : ["--no-acai"],
    local.has_pip_requirements ? ["--requirements"] : [],
    local.has_pip_requirements && local.pip_platform != null ? ["--pip-platform", local.pip_platform] : [],
    local.has_pip_requirements && local.pip_python_version != null ? ["--pip-python-version", local.pip_python_version] : [],
    local.has_inline_files ? ["--inline-files"] : [],
  )

  # Deterministic, input-based hash for the layer.
  # Used as `source_code_hash` so that `aws_lambda_layer_version` is only
  # replaced when the *inputs* change, not when the zip bytes happen to
  # differ (e.g. due to file mtimes embedded in the archive on a rebuild).
  # NOTE: compatible_runtimes / compatible_architectures are not included
  # here — they are first-class attributes of `aws_lambda_layer_version`
  # and already trigger a replacement on their own when changed.
  layer_inputs_hash = base64sha256(jsonencode({
    modules            = var.layer_settings.acai_modules
    acai_source        = local.acai_source_hash
    requirements       = local.pip_requirements_hash
    inline_files       = local.has_inline_files ? md5(local.inline_files_json) : ""
    pip_platform       = local.pip_platform
    pip_python_version = local.pip_python_version
  }))


  # Multi-region publishing: when var.regions is non-empty, publish a layer
  # version per region using the AWS provider v6 `region` resource argument.
  # When empty, publish a single layer version in the provider's default region
  regions_set = length(var.regions) > 0 ? toset(var.regions) : toset(["__default__"])
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ BUILD LAYER SOURCE + ZIP
# ---------------------------------------------------------------------------------------------------------------------
# The ZIP is built while Terraform *plans* (data sources are read during plan), so it exists
# whenever the layer version has to be published - also when plan and apply run in separate
# CI jobs (the terraform folder incl. .layer-build/ is handed over with the plan) and when
# only the layer version (not its inputs) has to be recreated, e.g. on a runtime change.
# A data source never shows up as a change: with unchanged inputs the plan stays empty
# (`filename` is a constant relative path, `source_code_hash` is input-based, not ZIP-byte based).
# The layer version only depends on the data source (depends_on) and does not read its
# result: if Terraform defers the data source to apply (e.g. module-level depends_on with
# pending changes), `filename` stays known and no replacement is planned.
# The former null_resource.build_layer either missed the ZIP (trigger on inputs only) or
# was replaced on every plan (timestamp() trigger).
data "external" "build_layer" {
  program = [local.is_windows ? "python" : "python3", "${path.module}/build_layer_external.py"]

  query = {
    output                = local.acai_powertools_layer_zip
    source_dir            = local.layer_source_folder
    inputs_hash           = local.layer_inputs_hash
    args                  = jsonencode(local.build_args)
    pip_requirements_json = local.pip_requirements_json
    inline_files_json     = local.inline_files_json
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LAMBDA LAYER (one per region — uses AWS provider v6 `region` argument)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lambda_layer_version" "acai_powertools_layer" {
  for_each = local.regions_set

  region                   = each.key == "__default__" ? null : each.key
  layer_name               = var.layer_settings.layer_name
  description              = var.layer_settings.description
  filename                 = local.layer_zip_filename
  compatible_runtimes      = var.layer_settings.compatible_runtimes
  compatible_architectures = var.layer_settings.compatible_architectures
  source_code_hash         = local.layer_inputs_hash
  skip_destroy             = var.layer_settings.skip_destroy

  depends_on = [data.external.build_layer]

  lifecycle {
    create_before_destroy = true
  }
}
