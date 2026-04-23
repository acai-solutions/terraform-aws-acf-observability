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

| Name | Source | Version |
|------|--------|---------|
| <a name="module_layer"></a> [layer](#module\_layer) | ./lambda-layer | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_oam_link.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/oam_link) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_settings"></a> [settings](#input\_settings) | Module Settings | <pre>object({<br/>    aws_regions = object({<br/>      primary   = string<br/>      secondary = list(string)<br/>    })<br/>    oam = object({<br/>      sink_identifiers = map(string)<br/>      resource_types   = optional(list(string), ["AWS::CloudWatch::Metric", "AWS::Logs::LogGroup", "AWS::XRay::Trace"])<br/>      log_group_filter = optional(string, null)<br/>      metric_filter    = optional(string, null)<br/>    })<br/>    lambda_layer = optional(object({<br/>      layer_base_name      = string<br/>      layer_runtimes       = list(string)<br/>      layer_architectures  = list(string)<br/>      ssm_parameter_prefix = optional(string, null)<br/>    }), null)<br/>  })</pre> | n/a | yes |
| <a name="input_resource_tags"></a> [resource\_tags](#input\_resource\_tags) | A map of tags to assign to the resources in this module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_layer_arns"></a> [layer\_arns](#output\_layer\_arns) | Layer ARNs keyed by variant, then by region (empty when lambda\_layer is null). |
| <a name="output_layer_ssm_parameter_arns"></a> [layer\_ssm\_parameter\_arns](#output\_layer\_ssm\_parameter\_arns) | ARNs of the per-variant, per-region SSM parameters (empty when lambda\_layer is null). |
| <a name="output_oam_link_arns"></a> [oam\_link\_arns](#output\_oam\_link\_arns) | ARNs of the OAM links, keyed by region. |
| <a name="output_oam_link_ids"></a> [oam\_link\_ids](#output\_oam\_link\_ids) | IDs of the OAM links, keyed by region. |
<!-- END_TF_DOCS -->