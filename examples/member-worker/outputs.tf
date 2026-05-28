# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
#
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


output "success_lambda_name" {
  description = "Name of the success demo lambda."
  value       = module.lambda_success.lambda.name
}

output "error_lambda_name" {
  description = "Name of the error demo lambda."
  value       = module.lambda_error.lambda.name
}
