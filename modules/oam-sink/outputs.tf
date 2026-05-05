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
  description = "ARN of the Lambda drill-down CloudWatch dashboard."
  value       = aws_cloudwatch_dashboard.lambda_drilldown.dashboard_arn
}
