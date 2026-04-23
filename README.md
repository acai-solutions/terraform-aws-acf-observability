# AWS ACF Observability Terraform module

<!-- SHIELDS -->
[![Maintained by acai.gmbh][acai-shield]][acai-url]
[![documentation][acai-docs-shield]][acai-docs-url]  
![module-version-shield]  
![terraform-tested-shield]
![opentofu-tested-shield]  
![aws-tested-shield]
![aws-esc-tested-shield]  
![trivy-shield]
![checkov-shield]

<!-- LOGO -->
<div style="text-align: right; margin-top: -60px;">
<a href="https://acai.gmbh">
  <img src="https://github.com/acai-consulting/acai.public/raw/main/logo/logo_github_readme.png" alt="acai logo" title="ACAI"  width="250" /></a>
</div>
</br>

<!-- BEGIN_ACAI_DOCS -->
<!-- DESCRIPTION -->
[Terraform][terraform-url] module to deploy cross-account **CloudWatch Observability Access Manager (OAM)** resources on [AWS][aws-url].

This module is part of the [ACAI Cloud Foundation (ACF)][acai-docs-url] and enables centralized, cross-account observability by establishing OAM sinks and links across an AWS Organization. It supports sharing CloudWatch Metrics, Log Groups and X-Ray Traces from multiple member accounts into a single monitoring account.

<!-- ARCHITECTURE -->
## Architecture

![architecture][architecture]

## Overview

AWS CloudWatch Observability Access Manager (OAM) allows you to link multiple AWS accounts (sources) to a central monitoring account (sink) so that telemetry data - metrics, logs and traces - from all source accounts becomes visible in the monitoring account's CloudWatch console without the need to switch between accounts.

This module automates the setup of that cross-account observability pattern:

| Component | Deployed to | Purpose |
|---|---|---|
| **OAM Sink** | Monitoring account | Receives shared telemetry from source accounts |
| **OAM Link** | Each source (member) account | Connects the member to the central sink |
| **CloudWatch Dashboard** | Monitoring account | Aggregated Lambda Invocations & Errors view |
| **Lambda Layer** *(optional)* | Each source (member) account | Standardized logging via ACAI Powertools |

Once deployed, the monitoring account can view **Log Groups**, **Metrics** and **Traces** from all linked member accounts - as shown in the screenshot below where log groups from two member accounts (`aws-testbed_core-logging` and `aws-testbed_core-backup`) appear in the monitoring account's CloudWatch console:

![monitoring-account][monitoring-account]

<!-- FEATURES -->
## Features

* **Multi-region deployment** - Sink and link resources are deployed to a configurable primary region plus any number of secondary regions.
* **OAM Sink with IAM policy** - Creates an OAM sink in the monitoring account with a sink policy that authorises specific member accounts to share `CloudWatch::Metric`, `Logs::LogGroup` and `XRay::Trace` resources.
* **OAM Link with filtering** - Creates OAM links in each member account. Supports optional `log_group_filter` and `metric_filter` to control which telemetry is shared.
* **CloudWatch Dashboard** - Automatically provisions a cross-account Lambda overview dashboard (Invocations & Errors) in the monitoring account. Supply `dashboard_settings` to replace the default widgets with a fully custom dashboard layout.
* **Lambda Layer provisioning** *(optional)* - Deploys a standardised ACAI Powertools Lambda layer across all regions with SSM parameter publication for easy layer discovery.
* **Logging Factory** - The layer ships with a built-in `logging_factory` module that wraps AWS Lambda Powertools into a single `setup_logging()` call, giving every Lambda a consistent, structured JSON log format out of the box.
* **Resource tagging** - All resources are tagged with module metadata (`acf_module_provider`, `acf_module_name`, `acf_sub_module_name`, `acf_module_source`) and support custom tags via `resource_tags`.
* **ACAI VECTO integration** - Ships with CI/CD principal templates (`oam_sink.tftpl`, `oam_member.tftpl`) that VECTO uses to provision pipeline-principals into each member core-account.
<!-- END_ACAI_DOCS -->

<!-- SUB-MODULES -->
## Sub-Modules

### oam-sink

**Path:** `modules/oam-sink`

Deployed in the **monitoring account**. Creates:

| Resource | Description |
|---|---|
| `aws_oam_sink` | One OAM sink per configured region |
| `aws_oam_sink_policy` | IAM policy authorising member accounts to create links |
| `aws_cloudwatch_dashboard` | Aggregated Lambda Invocations & Errors dashboard |

#### Inputs

| Name | Description | Type | Required |
|------|-------------|------|:--------:|
| `settings.aws_regions.primary` | Primary AWS region | `string` | yes |
| `settings.aws_regions.secondary` | List of secondary AWS regions | `list(string)` | yes |
| `settings.oam.sink_name` | Name for the OAM sink resources | `string` | yes |
| `settings.oam.trusted_account_ids` | Account IDs allowed to link to this sink | `list(string)` | yes |
| `dashboard_settings` | Custom CloudWatch dashboard body. When `null` (default), a Lambda Invocations & Errors dashboard is created automatically | `any` | no |
| `resource_tags` | Custom tags to merge onto all resources | `map(string)` | no |

#### Outputs

| Name | Description |
|------|-------------|
| `oam_sink_arns` | Map of OAM sink ARNs keyed by region |
| `oam_sink_ids` | Map of OAM sink IDs keyed by region |
| `lambda_dashboard_arn` | ARN of the Lambda overview CloudWatch dashboard |

---

### oam-member

**Path:** `modules/oam-member`

Deployed in each **source (member) account**. Creates:

| Resource | Description |
|---|---|
| `aws_oam_link` | One OAM link per configured region, connecting to the central sink |
| `module.layer` *(optional)* | ACAI Powertools Lambda layer deployed across all regions |

#### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `settings.aws_regions.primary` | Primary AWS region | `string` | - | yes |
| `settings.aws_regions.secondary` | List of secondary AWS regions | `list(string)` | - | yes |
| `settings.oam.sink_identifiers` | Map of sink ARNs keyed by region (from `oam_sink.oam_sink_arns`) | `map(string)` | - | yes |
| `settings.oam.resource_types` | Resource types to share | `list(string)` | `["AWS::CloudWatch::Metric", "AWS::Logs::LogGroup", "AWS::XRay::Trace"]` | no |
| `settings.oam.log_group_filter` | Filter expression for log group sharing | `string` | `null` | no |
| `settings.oam.metric_filter` | Filter expression for metric sharing | `string` | `null` | no |
| `settings.lambda_layer` | Lambda layer configuration (set to `null` to skip) | `object` | `null` | no |
| `settings.lambda_layer.layer_base_name` | Base name for the Lambda layer | `string` | - | conditional |
| `settings.lambda_layer.layer_runtimes` | Runtimes for the layer (e.g. `["python3.12"]`) | `list(string)` | - | conditional |
| `settings.lambda_layer.layer_architectures` | Architectures for the layer (e.g. `["arm64"]`) | `list(string)` | - | conditional |
| `settings.lambda_layer.ssm_parameter_prefix` | Custom SSM prefix for layer ARN publication | `string` | `null` | no |
| `resource_tags` | Custom tags to merge onto all resources | `map(string)` | `{}` | no |

#### Outputs

| Name | Description |
|------|-------------|
| `oam_link_arns` | Map of OAM link ARNs keyed by region |
| `oam_link_ids` | Map of OAM link IDs keyed by region |
| `layer_arns` | Layer ARNs keyed by variant then region (empty when `lambda_layer` is `null`) |
| `layer_ssm_parameter_arns` | SSM parameter ARNs for each variant/region combo |

---

### lambda-layer (nested)

**Path:** `modules/oam-member/lambda-layer`

Automatically invoked by `oam-member` when `settings.lambda_layer` is provided. Handles:

* Building a matrix of `(runtime, architecture)` layer variants.
* Deploying each variant via the `acai-powertools` module across all configured regions.
* Publishing each layer's ARN as an SSM Parameter for downstream discovery.

Layer variants are named `{layer_base_name}-{runtime}{arch}` (e.g. `acme-powertools-m1-python312-arm64`).

SSM parameters are published at:
```
/{ssm_parameter_prefix}/lambda-layers/{layer_base_name}/{variant}/arn
```

<!-- USAGE -->
## Usage

### Step 1 - Deploy the OAM Sink (Monitoring Account)

Deploy the sink in your central monitoring/security account:

```hcl
module "oam_sink" {
  source = "github.com/acai-solutions/terraform-aws-acf-observability//modules/oam-sink"

  settings = {
    aws_regions = {
      primary   = "eu-central-1"
      secondary = ["eu-west-1"]
    }
    oam = {
      sink_name           = "acf-central-observability"
      trusted_account_ids = ["111111111111", "222222222222"]
    }
  }

  # Optional: supply a custom dashboard layout.
  # When omitted (null), a default Lambda Invocations & Errors dashboard is created.
  # dashboard_settings = { widgets = [ ... ] }

  resource_tags = {
    environment = "production"
  }
}
```

### Step 2 - Deploy OAM Members (Source Accounts)

For each member account, create a link back to the sink. Pass the sink ARNs from Step 1:

```hcl
module "oam_member" {
  source = "github.com/acai-solutions/terraform-aws-acf-observability//modules/oam-member"

  settings = {
    aws_regions = {
      primary   = "eu-central-1"
      secondary = ["eu-west-1"]
    }
    oam = {
      sink_identifiers = module.oam_sink.oam_sink_arns
    }
  }
}
```

### Step 3 - Deploy with Lambda Layer (optional)

To also deploy a standardised ACAI Powertools Lambda layer in the member account:

```hcl
module "oam_member" {
  source = "github.com/acai-solutions/terraform-aws-acf-observability//modules/oam-member"

  settings = {
    aws_regions = {
      primary   = "eu-central-1"
      secondary = ["eu-west-1"]
    }
    oam = {
      sink_identifiers = module.oam_sink.oam_sink_arns
      log_group_filter = "LogGroupName LIKE '/aws/lambda/my-app-'"
    }
    lambda_layer = {
      layer_base_name     = "acme-powertools"
      layer_runtimes      = ["python3.12"]
      layer_architectures = ["arm64"]
    }
  }
}
```

The deployed layer ARN can then be referenced in Lambda functions:

```hcl
resource "aws_lambda_function" "my_function" {
  # ...
  layers = [module.oam_member.layer_arns["python312-arm64"]["eu-central-1"]]
}
```

<!-- LOGGING FACTORY -->
## Logging Factory

The Lambda layer includes an inline **Logging Factory** module (`acme/logging_factory.py`) that wraps [AWS Lambda Powertools](https://docs.powertools.aws.dev/lambda/python/latest/) into a single convenience function. This ensures every Lambda function that uses the layer produces consistent, structured JSON logs that are directly searchable in CloudWatch Logs Insights.

### How it works

```python
# acme/logging_factory.py  (shipped inside the layer)
import os
from acai.logging import LoggerContext, create_lambda_logger
from acai.logging.domain import Logger, LoggerConfig

def setup_logging(service_name: str, log_level: str | None = None) -> Logger:
    config = LoggerConfig(
        service_name=service_name,
        log_level=log_level or os.getenv("LOG_LEVEL", "INFO").upper(),
    )
    return create_lambda_logger(config)
```

### Usage in a Lambda function

```python
from acme.logging_factory import setup_logging

logger = setup_logging(service_name="my-service")

@logger.inject_lambda_context()
def lambda_handler(event, context):
    logger.info("Processing request.")
    logger.debug(f"Received event: {event}")
    return {"statusCode": 200, "body": "OK"}
```

**Key benefits:**

* **One-liner setup** - `setup_logging(service_name="...")` replaces all boilerplate logger configuration.
* **Structured JSON output** - Every log entry is emitted as JSON with `service`, `level`, `timestamp`, `function_name`, `request_id` and custom fields.
* **Lambda context injection** - The `@logger.inject_lambda_context()` decorator automatically enriches every log line with the Lambda request ID, function name and memory settings.
* **Environment-driven log level** - Defaults to the `LOG_LEVEL` environment variable (or `INFO`), so you can change verbosity without code changes.
* **ACAI Powertools modules** - The layer bundles `logging`, `boto3_helper`, `python_helper` and `storage` from ACAI Powertools plus `aws-lambda-powertools`.

<!-- EXAMPLES -->
## Examples

* [`_example/complete`][example-complete-url] - Full end-to-end demo that deploys:
  * An OAM sink in a security account
  * Two OAM members (logging and backup accounts) with Lambda layers
  * Demo Lambda functions (success + error) in each member account
  * Lambda invocations to validate cross-account visibility

## Integration with ACAI VECTO

This module ships with CI/CD principal templates in `cicd-principals/acai-vecto/` for integration with [ACAI VECTO][acai-docs-url] deployment pipelines. VECTO uses these CloudFormation templates to **provision pipeline-principals (IAM roles) into each member core-account** before the Terraform run, so the pipeline has the exact permissions needed to manage observability resources.

| Template | Provisioned to | IAM Permissions Granted |
|---|---|---|
| `oam_sink.tftpl` | Monitoring account (OAM Sink) | `oam:CreateSink`, `oam:PutSinkPolicy`, `cloudwatch:PutDashboard`, and related read/tag actions |
| `oam_member.tftpl` | Each source core-account (OAM Member) | `oam:CreateLink`, `lambda:PublishLayerVersion`, `ssm:PutParameter`, and related read/tag actions |

The workflow is:

1. **VECTO provisions principals** - The pipeline renders `oam_sink.tftpl` and `oam_member.tftpl` with the trustee role ARN and deploys the resulting CloudFormation stacks to each target core-account. This creates the least-privilege IAM roles the pipeline will later assume.
2. **Pipeline assumes provisioned roles** - The Terraform run assumes the newly created roles in the monitoring account and each member account.
3. **Terraform deploys observability resources** - The `oam-sink` module runs in the monitoring account; the `oam-member` module runs in each source core-account, creating OAM links, Lambda layers and SSM parameters.

<!-- AUTHORS -->
## Authors

This module is maintained by [ACAI GmbH][acai-url].

<!-- LICENSE -->
## License

See [LICENSE][license-url] for full details.

<!-- COPYRIGHT -->
<br />
<br />
<p align="center">Copyright ACAI GmbH</p>

<!-- MARKDOWN LINKS & IMAGES -->
[acai-shield]: https://img.shields.io/badge/maintained_by-acai.gmbh-CB224B?style=flat
[acai-url]: https://acai.gmbh
[acai-docs-shield]: https://img.shields.io/badge/documentation-docs.acai.gmbh-CB224B?style=flat
[acai-docs-url]: https://docs.acai.gmbh/solution-acf/10_overview/
[module-version-shield]: https://img.shields.io/badge/module_version-1.0.0-CB224B?style=flat
[module-release-url]: ./releases
[terraform-tested-shield]: https://img.shields.io/badge/terraform-%3E%3D1.5.7_tested-844FBA?style=flat&logo=terraform&logoColor=white
[opentofu-tested-shield]: https://img.shields.io/badge/opentofu-%3E%3D1.6_tested-FFDA18?style=flat&logo=opentofu&logoColor=black
[aws-tested-shield]: https://img.shields.io/badge/AWS-%E2%9C%93_tested-FF9900?style=flat&logo=amazonaws&logoColor=white
[aws-esc-tested-shield]: https://img.shields.io/badge/AWS_ESC-%E2%9C%93_tested-003399?style=flat&logo=amazonaws&logoColor=white
[trivy-shield]: https://img.shields.io/badge/trivy-passed-green
[checkov-shield]: https://img.shields.io/badge/checkov-passed-green
[architecture]: ./docs/terraform-aws-acf-observability.png
[monitoring-account]: ./docs/monitoring-account.png
[example-complete-url]: ./_example/complete
[license-url]: ./LICENSE.md
[terraform-url]: https://www.terraform.io
[aws-url]: https://aws.amazon.com
