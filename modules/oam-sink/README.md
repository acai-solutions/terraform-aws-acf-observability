<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_dashboard.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_oam_sink.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/oam_sink) | resource |
| [aws_oam_sink_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/oam_sink_policy) | resource |
| [aws_iam_policy_document.oam_sink](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_settings"></a> [settings](#input\_settings) | Module Settings | <pre>object({<br/>    aws_regions = object({<br/>      primary   = string<br/>      secondary = list(string)<br/>    })<br/>    oam = object({<br/>      sink_name           = string<br/>      trusted_account_ids = list(string)<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_resource_tags"></a> [resource\_tags](#input\_resource\_tags) | A map of tags to assign to the resources in this module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda_dashboard_arn"></a> [lambda\_dashboard\_arn](#output\_lambda\_dashboard\_arn) | ARN of the Lambda overview CloudWatch dashboard. |
| <a name="output_oam_sink_arns"></a> [oam\_sink\_arns](#output\_oam\_sink\_arns) | ARNs of the OAM sinks, keyed by region. Depends on the sink policy so that consumers can safely create links. |
| <a name="output_oam_sink_ids"></a> [oam\_sink\_ids](#output\_oam\_sink\_ids) | IDs of the OAM sinks, keyed by region. |
<!-- END_TF_DOCS -->