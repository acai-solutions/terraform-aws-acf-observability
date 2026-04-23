output "layer_arns" {
  description = "Layer ARNs keyed by variant (e.g. 'python312-arm64'), then by region."
  value       = { for variant, m in module.layer : variant => m.layer_arns }
}

output "layer_ssm_parameter_arns" {
  description = "ARNs of the per-variant, per-region SSM parameters, keyed 'variant/region'."
  value       = { for k, p in aws_ssm_parameter.layer_arn : k => p.arn }
}
