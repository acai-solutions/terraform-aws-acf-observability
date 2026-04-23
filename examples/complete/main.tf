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
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  regions = {
    primary   = var.aws_region
    secondary = var.aws_partition == "aws" ? ["eu-west-1"] : []
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ OAM SINK — central monitoring account (two regions)
# ---------------------------------------------------------------------------------------------------------------------
module "oam_sink" {
  source = "../../modules/oam-sink"

  settings = {
    aws_regions = local.regions
    oam = {
      sink_name           = "acf-observability-demo"
      trusted_account_ids = [var.account_ids.core_logging, var.account_ids.core_backup]
    }
  }
  providers = {
    aws = aws.sink_provisioner
  }
  depends_on = [module.create_sink_provisioner]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ OAM MEMBER 1 — linked to sink, deploys two demo lambdas
# ---------------------------------------------------------------------------------------------------------------------
module "oam_member_1" {
  source = "../../modules/oam-member"

  settings = {
    aws_regions = local.regions
    oam = {
      sink_identifiers = module.oam_sink.oam_sink_arns
    }
    lambda_layer = {
      layer_base_name     = "acme-powertools-m1"
      layer_runtimes      = ["python3.12"]
      layer_architectures = ["arm64"]
    }
  }
  providers = {
    aws = aws.member_1_provisioner
  }
  depends_on = [module.create_member_1_provisioner]
}

module "member_1_worker" {
  source      = "./member-worker"
  member_name = "member-1"
  layer_arn   = module.oam_member_1.layer_arns["python312-arm64"][var.aws_region]
  providers = {
    aws = aws.core_logging
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ OAM MEMBER 2 — linked to sink, deploys two demo lambdas
# ---------------------------------------------------------------------------------------------------------------------
module "oam_member_2" {
  source = "../../modules/oam-member"

  settings = {
    aws_regions = local.regions
    oam = {
      sink_identifiers = module.oam_sink.oam_sink_arns
    }
    lambda_layer = {
      layer_base_name     = "acme-powertools-m2"
      layer_runtimes      = ["python3.12"]
      layer_architectures = ["arm64"]
    }
  }
  providers = {
    aws = aws.member_2_provisioner
  }
  depends_on = [module.create_member_2_provisioner]
}

module "member_2_worker" {
  source      = "./member-worker"
  member_name = "member-2"
  layer_arn   = module.oam_member_2.layer_arns["python312-arm64"][var.aws_region]
  providers = {
    aws = aws.core_backup
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ INVOKE SUCCESS LAMBDAS — results visible in terraform output
# ---------------------------------------------------------------------------------------------------------------------
resource "time_sleep" "wait_for_lambdas" {
  depends_on      = [module.member_1_worker, module.member_2_worker]
  create_duration = "10s"
}

resource "aws_lambda_invocation" "member_1_success" {
  function_name = module.member_1_worker.success_lambda_name
  input         = jsonencode({ source = "terraform", member = "member-1" })
  provider      = aws.core_logging
  depends_on    = [time_sleep.wait_for_lambdas]
}

resource "aws_lambda_invocation" "member_2_success" {
  function_name = module.member_2_worker.success_lambda_name
  input         = jsonencode({ source = "terraform", member = "member-2" })
  provider      = aws.core_backup
  depends_on    = [time_sleep.wait_for_lambdas]
}
