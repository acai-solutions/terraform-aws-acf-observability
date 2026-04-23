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
# ¦ CREATE PROVISIONERS — least-privilege IAM roles in each target account
# ---------------------------------------------------------------------------------------------------------------------
module "create_sink_provisioner" {
  source = "../../cicd-principals/terraform-oam-sink"

  iam_role_settings = {
    name = "cicd_oam_sink_provisioner"
    aws_trustee_arns = [
      "arn:${var.aws_partition}:iam::${var.account_ids.org_mgmt}:root"
    ]
  }
  providers = {
    aws = aws.core_security
  }
}

module "create_member_1_provisioner" {
  source = "../../cicd-principals/terraform-oam-member"

  iam_role_settings = {
    name = "cicd_oam_member_provisioner"
    aws_trustee_arns = [
      "arn:${var.aws_partition}:iam::${var.account_ids.org_mgmt}:root"
    ]
  }
  providers = {
    aws = aws.core_logging
  }
}

module "create_member_2_provisioner" {
  source = "../../cicd-principals/terraform-oam-member"

  iam_role_settings = {
    name = "cicd_oam_member_provisioner"
    aws_trustee_arns = [
      "arn:${var.aws_partition}:iam::${var.account_ids.org_mgmt}:root"
    ]
  }
  providers = {
    aws = aws.core_backup
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ PROVIDERS — assume the provisioner roles
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region
  alias  = "sink_provisioner"
  assume_role {
    role_arn = module.create_sink_provisioner.iam_role_arn
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "member_1_provisioner"
  assume_role {
    role_arn = module.create_member_1_provisioner.iam_role_arn
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "member_2_provisioner"
  assume_role {
    role_arn = module.create_member_2_provisioner.iam_role_arn
  }
}
