import logging
import boto3
import os
from typing import Dict, Any, Optional
import json
import urllib.parse

logger = logging.getLogger()
logger.setLevel(logging.INFO)

bedrock = boto3.client('bedrock-runtime')
s3 = boto3.client('s3')
eventbridge = boto3.client('events')

CUSTOM_BUS_NAME = os.environ.get('CUSTOM_BUS_NAME', '${custom_bus_name}')
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', '${bedrock_model_id}')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    try:
        logger.info(f"Processign S3 event: {json.dumps(event)}")

        bucket = event['Records'][0]['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'])

        logger.info(f"Analyzing content from s3://{bucket}/{key}")

        content = get_content_from_s3(bucket, key)

        if not content:
            logger.warning(f"No content found or content is empty for {key}")
            return create_response(200, "No content to analyze")
        
        moderation_result = analyze_content_with_bedrock(content)
        event_published = publish_moderation_event(bucket, key, moderation_result)

        if event_published:
            logger.info(f"Successfully processed content {key} with decision: {moderation_result['decision']}")
            return create_response(200, {
                'message': 'Content analyzed successfully',
                'decision': moderation_result['decision'],
                'confidence': moderation_result['confidence']
            })
        else:
            logger.error(f"Failed to publish event for content {key}")
            return create_response(500, "Failed to publish moderation event")
        
    except Exception as e:
        logger.error(f"Error processing content: {str(e)}", exc_info=True)
        return create_response(500, "Failed to publish moderation event")
    

def create_response(status_code: int, body: str) -> Dict[str, Any]:
    """
    Helper function to create a standardized response.

    Args:
        status_code: HTTP status code
        body: Response body content

    Returns:
        Formatted Lmabda response dictionary
    """

    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'X-Content-Analysis': 'bedrock-claude'
        },
        'body': json.dumps(body) if isinstance(body, (dict, list)) else str(body)
    }

