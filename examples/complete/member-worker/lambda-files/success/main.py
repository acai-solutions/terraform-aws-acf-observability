"""Observability demo — success lambda."""

from acme.logging_factory import setup_logging

logger = setup_logging(service_name="acf-obs-demo-success")


@logger.inject_lambda_context()
def lambda_handler(event, context):
    logger.info("Observability demo: success lambda invoked.")
    logger.debug(f"Received event: {event}")
    return {
        "statusCode": 200,
        "body": {"message": "Success!", "input": event},
    }
