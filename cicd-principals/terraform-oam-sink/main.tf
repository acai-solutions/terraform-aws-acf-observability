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
      source                = "hashicorp/aws"
      version               = ">= 6.0"
      configuration_aliases = []
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ IAM ROLE — OAM Sink provisioner
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "cicd_principal" {
  name                 = var.iam_role_settings.name
  path                 = var.iam_role_settings.path
  permissions_boundary = var.iam_role_settings.permissions_boundary_arn
  description          = "IAM Role used to provision OAM Sink, Sink Policy and CloudWatch Dashboard resources"
  assume_role_policy   = data.aws_iam_policy_document.assume_role_policy.json
  tags                 = var.resource_tags
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.iam_role_settings.aws_trustee_arns
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ IAM POLICY — least-privilege for oam-sink module resources
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy" "oam_sink" {
  name   = "OamSinkProvisioning"
  role   = aws_iam_role.cicd_principal.id
  policy = data.aws_iam_policy_document.oam_sink_policy.json
}

#tfsec:ignore:AVD-AWS-0057
data "aws_iam_policy_document" "oam_sink_policy" {
  #checkov:skip=CKV_AWS_111
  #checkov:skip=CKV_AWS_356
  statement {
    sid    = "AllowOamSinkManagement"
    effect = "Allow"
    actions = [
      "oam:CreateSink",
      "oam:DeleteSink",
      "oam:GetSink",
      "oam:ListSinks",
      "oam:PutSinkPolicy",
      "oam:GetSinkPolicy",
      "oam:TagResource",
      "oam:UntagResource",
      "oam:ListTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchDashboard"
    effect = "Allow"
    actions = [
      "cloudwatch:PutDashboard",
      "cloudwatch:DeleteDashboards",
      "cloudwatch:GetDashboard",
      "cloudwatch:ListDashboards",
      "logs:PutQueryDefinition",
      "logs:DescribeQueryDefinitions",
      "logs:DeleteQueryDefinition",
    ]
    resources = ["*"]
  }
}
