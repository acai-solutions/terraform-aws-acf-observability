# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
#
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


variable "member_name" {
  type        = string
  description = "Unique name for this member (used in resource naming)."
}

variable "layer_arn" {
  type        = string
  description = "ARN of the acme powertools Lambda layer."
}

variable "resource_tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
