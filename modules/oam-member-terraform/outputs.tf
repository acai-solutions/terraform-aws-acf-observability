output "oam_link_arns" {
  description = "ARNs of the OAM links, keyed by region."
  value       = { for region, link in aws_oam_link.this : region => link.arn }
}

output "oam_link_ids" {
  description = "IDs of the OAM links, keyed by region."
  value       = { for region, link in aws_oam_link.this : region => link.id }
}

output "layer_arns" {
  description = "Layer ARNs keyed by variant, then by region (empty when lambda_layer is null)."
  value       = var.settings.lambda_layer != null ? module.layer[0].layer_arns : {}
}

output "layer_ssm_parameter_arns" {
  description = "ARNs of the per-variant, per-region SSM parameters (empty when lambda_layer is null)."
  value       = var.settings.lambda_layer != null ? module.layer[0].layer_ssm_parameter_arns : {}
}

output "cw_cross_account_list_accounts_role_arn" {
  description = "ARN of the CloudWatch-CrossAccountSharing-ListAccountsRole created in the Org Management account. Null elsewhere."
  value       = try(aws_iam_role.cw_cross_account_list_accounts[0].arn, null)
}
