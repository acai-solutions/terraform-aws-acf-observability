"""Observability demo — success lambda."""

from acme.logging_factory import LoggerContext, setup_logging

logger = setup_logging(service_name="acf-obs-demo-success")


@logger.inject_lambda_context()
def lambda_handler(event, context):
    logger.info("Observability demo: success lambda invoked.")
    logger.debug(f"Received event: {event}")

    with LoggerContext(logger, {"demo_scope": "success-handler"}):
        logger.info("Inside scoped LoggerContext block.")

    return {
        "statusCode": 200,
        "body": {"message": "Success!", "input": event},
    }
