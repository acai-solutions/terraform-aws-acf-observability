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
# ¦ IAM ROLE — OAM Member provisioner
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "cicd_principal" {
  name                 = var.iam_role_settings.name
  path                 = var.iam_role_settings.path
  permissions_boundary = var.iam_role_settings.permissions_boundary_arn
  description          = "IAM Role used to provision OAM Link, Lambda Layer and SSM Parameter resources"
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
# ¦ IAM POLICY — least-privilege for oam-member module resources
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy" "oam_member" {
  name   = "OamMemberProvisioning"
  role   = aws_iam_role.cicd_principal.id
  policy = data.aws_iam_policy_document.oam_member_policy.json
}

#tfsec:ignore:AVD-AWS-0057
data "aws_iam_policy_document" "oam_member_policy" {
  #checkov:skip=CKV_AWS_108: OAM, Lambda layer and SSM actions require wildcard resources
  #checkov:skip=CKV_AWS_109: OAM, Lambda layer and SSM actions require wildcard resources
  #checkov:skip=CKV_AWS_111
  #checkov:skip=CKV_AWS_356
  statement {
    sid    = "AllowOamLinkManagement"
    effect = "Allow"
    actions = [
      "oam:CreateLink",
      "oam:DeleteLink",
      "oam:GetLink",
      "oam:UpdateLink",
      "oam:ListLinks",
      "oam:TagResource",
      "oam:UntagResource",
      "oam:ListTagsForResource",
      "cloudwatch:Link",
      "logs:Link",
      "xray:Link",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowLambdaLayerManagement"
    effect = "Allow"
    actions = [
      "lambda:PublishLayerVersion",
      "lambda:DeleteLayerVersion",
      "lambda:GetLayerVersion",
      "lambda:GetLayerVersionPolicy",
      "lambda:ListLayerVersions",
      "lambda:ListLayers",
      "lambda:AddLayerVersionPermission",
      "lambda:RemoveLayerVersionPermission",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowSsmParameterManagement"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:DescribeParameters",
      "ssm:AddTagsToResource",
      "ssm:RemoveTagsFromResource",
      "ssm:ListTagsForResource",
    ]
    resources = ["*"]
  }
}
