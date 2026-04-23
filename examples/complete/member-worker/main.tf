# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
#
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


# ---------------------------------------------------------------------------------------------------------------------
# ¦ VERSIONS
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
# ¦ LAMBDA: SUCCESS — returns a normal response
# ---------------------------------------------------------------------------------------------------------------------
module "lambda_success" {
  source = "../../../modules-external/terraform-aws-lambda"

  lambda_settings = {
    function_name  = "acf-obs-demo-success-${var.member_name}"
    description    = "Observability demo — success lambda (${var.member_name})"
    handler        = "main.lambda_handler"
    layer_arn_list = [var.layer_arn]
    config = {
      runtime      = "python3.12"
      architecture = "arm64"
    }
    package = {
      source_path = "${path.module}/lambda-files/success"
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ LAMBDA: ERROR — raises an exception to trigger CloudWatch error metrics
# ---------------------------------------------------------------------------------------------------------------------
module "lambda_error" {
  source = "../../../modules-external/terraform-aws-lambda"

  lambda_settings = {
    function_name  = "acf-obs-demo-error-${var.member_name}"
    description    = "Observability demo — error lambda (${var.member_name})"
    handler        = "error.lambda_handler"
    layer_arn_list = [var.layer_arn]
    config = {
      runtime      = "python3.12"
      architecture = "arm64"
    }
    package = {
      source_path = "${path.module}/lambda-files/error"
    }
  }
}
