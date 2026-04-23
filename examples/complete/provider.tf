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
# ¦ PROVIDER
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region
  alias  = "org_mgmt"

  dynamic "assume_role" {
    for_each = var.iam_role_name != "" ? [1] : []
    content {
      role_arn = "arn:${var.aws_partition}:iam::${var.account_ids.org_mgmt}:role/${var.iam_role_name}"
    }
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "core_logging"

  dynamic "assume_role" {
    for_each = var.iam_role_name != "" ? [1] : []
    content {
      role_arn = "arn:${var.aws_partition}:iam::${var.account_ids.core_logging}:role/${var.iam_role_name}"
    }
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "core_security"

  dynamic "assume_role" {
    for_each = var.iam_role_name != "" ? [1] : []
    content {
      role_arn = "arn:${var.aws_partition}:iam::${var.account_ids.core_security}:role/${var.iam_role_name}"
    }
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "core_backup"

  dynamic "assume_role" {
    for_each = var.iam_role_name != "" ? [1] : []
    content {
      role_arn = "arn:${var.aws_partition}:iam::${var.account_ids.core_backup}:role/${var.iam_role_name}"
    }
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "workload"

  dynamic "assume_role" {
    for_each = var.iam_role_name != "" ? [1] : []
    content {
      role_arn = "arn:${var.aws_partition}:iam::${var.account_ids.workload}:role/${var.iam_role_name}"
    }
  }
}
