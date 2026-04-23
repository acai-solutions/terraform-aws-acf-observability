"""Observability demo — error lambda.

Raises an unhandled exception so the invocation appears as an error
in the AWS/Lambda CloudWatch Errors metric and on the dashboard.
"""

from acme.logging_factory import setup_logging

logger = setup_logging(service_name="acf-obs-demo-error")


@logger.inject_lambda_context()
def lambda_handler(event, context):
    logger.info("Observability demo: error lambda invoked.")
    logger.error("Intentional error for CloudWatch error dashboard demo.")
    raise RuntimeError(
        "Intentional failure — this error should appear on the CloudWatch error dashboard."
    )
