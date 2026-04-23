# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
#
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


output "oam_sink_arns" {
  description = "OAM sink ARNs by region."
  value       = module.oam_sink.oam_sink_arns
}

output "oam_member_1_link_arns" {
  description = "OAM member 1 link ARNs by region."
  value       = module.oam_member_1.oam_link_arns
}

output "oam_member_2_link_arns" {
  description = "OAM member 2 link ARNs by region."
  value       = module.oam_member_2.oam_link_arns
}

output "lambda_dashboard_arn" {
  description = "CloudWatch dashboard ARN for Lambda overview."
  value       = module.oam_sink.lambda_dashboard_arn
}

output "member_1_success_result" {
  description = "Result of invoking the success lambda in member 1."
  value       = jsondecode(aws_lambda_invocation.member_1_success.result)
}

output "member_2_success_result" {
  description = "Result of invoking the success lambda in member 2."
  value       = jsondecode(aws_lambda_invocation.member_2_success.result)
}

output "error_lambda_names" {
  description = "Names of the error lambdas (invoke via run_aws.ps1 to trigger dashboard errors)."
  value = {
    member_1 = module.member_1_worker.error_lambda_name
    member_2 = module.member_2_worker.error_lambda_name
  }
}

output "example_passed" {
  description = "Indicates whether the example deployed and executed successfully."
  value = tostring(
    jsondecode(aws_lambda_invocation.member_1_success.result)["statusCode"] == 200 &&
    jsondecode(aws_lambda_invocation.member_2_success.result)["statusCode"] == 200
  )
}
