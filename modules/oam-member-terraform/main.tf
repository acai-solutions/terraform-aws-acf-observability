# ---------------------------------------------------------------------------------------------------------------------
# ¦ REQUIREMENTS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_organizations_organization" "current" {}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  resource_tags = merge(
    var.resource_tags,
    {
      "acf_module_provider" = "ACAI GmbH",
      "acf_module_name"     = "terraform-aws-acf-observability",
      "acf_sub_module_name" = "oam-member",
      "acf_module_source"   = "github.com/acai-solutions/terraform-aws-acf-observability",
    }
  )

  all_regions = toset(concat(
    [var.settings.aws_regions.primary],
    var.settings.aws_regions.secondary
  ))
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ OAM LINK — connect this member account to the central sink in every region
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_oam_link" "this" {
  for_each = var.settings.oam == null ? toset([]) : local.all_regions

  region          = each.value
  sink_identifier = var.settings.oam.sink_identifiers[each.value]
  label_template  = "$AccountName"
  resource_types  = var.settings.oam.resource_types

  dynamic "link_configuration" {
    for_each = var.settings.oam.log_group_filter != null || var.settings.oam.metric_filter != null ? [1] : []
    content {
      dynamic "log_group_configuration" {
        for_each = var.settings.oam.log_group_filter != null ? [var.settings.oam.log_group_filter] : []
        content {
          filter = log_group_configuration.value
        }
      }
      dynamic "metric_configuration" {
        for_each = var.settings.oam.metric_filter != null ? [var.settings.oam.metric_filter] : []
        content {
          filter = metric_configuration.value
        }
      }
    }
  }

  tags = local.resource_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ OPTIONAL LOGGING LAYER — deploy the powertools layer to all regions
# ---------------------------------------------------------------------------------------------------------------------
module "layer" {
  source = "./lambda-layer"
  count  = var.settings.lambda_layer != null ? 1 : 0

  layer_settings = var.settings.lambda_layer
  regions        = tolist(local.all_regions)

  resource_tags = local.resource_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CLOUDWATCH CROSS-ACCOUNT — ORG MGMT ONLY
# ¦ In the Org Management account, a role with a fixed name is required so the
# ¦ CloudWatch monitoring console can list organization accounts and populate
# ¦ the account selector. The monitoring account ID is derived from any of the
# ¦ OAM sink ARNs (all sinks live in that account).
# ---------------------------------------------------------------------------------------------------------------------

locals {
  is_org_management_account = data.aws_caller_identity.current.account_id == data.aws_organizations_organization.current.master_account_id

  # Parse the monitoring account ID out of any sink ARN.
  # OAM sink ARN format: arn:aws:oam:<region>:<account-id>:sink/<uuid>
  monitoring_account_id = var.settings.oam == null ? null : split(":", values(var.settings.oam.sink_identifiers)[0])[4]
}

resource "aws_iam_role" "cw_cross_account_list_accounts" {
  count = var.settings.oam != null && local.is_org_management_account ? 1 : 0

  name               = "CloudWatch-CrossAccountSharing-ListAccountsRole"
  assume_role_policy = data.aws_iam_policy_document.cw_cross_account_list_accounts_trust[0].json
  tags               = local.resource_tags
}

# Trust policy per AWS Support: monitoring account root (the console signs the
# AssumeRole call from the monitoring account; no service principal involved).
data "aws_iam_policy_document" "cw_cross_account_list_accounts_trust" {
  count = var.settings.oam != null && local.is_org_management_account ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.monitoring_account_id}:root"]
    }
  }
}

data "aws_iam_policy_document" "cw_cross_account_list_accounts" {
  count = var.settings.oam != null && local.is_org_management_account ? 1 : 0

  statement {
    # checkov:skip=CKV_AWS_356: organizations:Describe*/List* actions do not support resource-level permissions
    sid    = "OrganizationsReadOnly"
    effect = "Allow"
    actions = [
      "organizations:Describe*",
      "organizations:List*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cw_cross_account_list_accounts" {
  count = var.settings.oam != null && local.is_org_management_account ? 1 : 0

  name   = "CloudWatch-CrossAccountSharing-ListAccounts-Policy"
  role   = aws_iam_role.cw_cross_account_list_accounts[0].name
  policy = data.aws_iam_policy_document.cw_cross_account_list_accounts[0].json
}
