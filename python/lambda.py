import boto3
import os

def lambda_handler(event, context):
    # Extract message from the event
    message = event['Records'][0]['body']

    # Process the message (customize this part based on your use case)
    print(f"Received message from SQS: {message}")

    # Example: Publish a response to another SQS queue or perform additional actions

    return {
        'statusCode': 200,
        'body': 'Message processed successfully'
    }
