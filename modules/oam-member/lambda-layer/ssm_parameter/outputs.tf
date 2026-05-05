output "ssm_parameter_arns" {
  description = "Map of region => SSM parameter ARN for this variant."
  value       = { for r, p in aws_ssm_parameter.layer_arn : r => p.arn }
}
