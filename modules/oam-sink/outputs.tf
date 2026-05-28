output "oam_sink_arns" {
  description = "ARNs of the OAM sinks, keyed by region. Depends on the sink policy so that consumers can safely create links."
  value       = { for region, policy in aws_oam_sink_policy.this : region => policy.sink_identifier }
}

output "oam_sink_ids" {
  description = "IDs of the OAM sinks, keyed by region."
  value       = { for region, sink in aws_oam_sink.this : region => sink.id }
}

output "lambda_dashboard_arn" {
  description = "ARN of the Lambda overview CloudWatch dashboard."
  value       = aws_cloudwatch_dashboard.lambda_overview.dashboard_arn
}

output "lambda_drilldown_dashboard_arn" {
  description = "ARN of the Lambda drill-down CloudWatch dashboard. Null when no explicit trusted_account_ids are configured (org-wide trust)."
  value       = try(aws_cloudwatch_dashboard.lambda_drilldown[0].dashboard_arn, null)
}

output "cw_cross_account_v2_role_arn" {
  description = "ARN of the ServiceRoleForCloudWatchCrossAccountV2 role in the monitoring account. Null when create_cw_cross_account_v2_role is false."
  value       = try(aws_iam_role.cw_cross_account_v2[0].arn, null)
}
