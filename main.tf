terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_sns_topic" "my_topic" {
  name = "my-topic"
}

resource "aws_sqs_queue" "my_queue" {
  name = "my-queue"
  tags = {
    Environment = "Dev"
  }
}

resource "aws_sns_topic_subscription" "my_sns_subscription" {
  topic_arn = aws_sns_topic.my_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.my_queue.arn
}

data "aws_iam_policy_document" "test" {
  statement {
    sid    = "First"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.my_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.my_topic.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "test" {
  queue_url = aws_sqs_queue.my_queue.id
  policy    = data.aws_iam_policy_document.test.json
}


# Define the Lambda function source code (place your Lambda function code in a zip file)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/python"
  output_path = "${path.module}/python/lambda.zip"
}

resource "aws_s3_bucket" "my_s3_bucket" {
  bucket = "my-s3-bucket-ms"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}


resource "aws_s3_object" "my_s3_object" {
  bucket = aws_s3_bucket.my_s3_bucket.id
  key    = "lambda.zip"
  source = "${path.module}/python/lambda.zip"
}

# Define the Lambda function
resource "aws_lambda_function" "my_lambda_function" {
  function_name = "my-lambda-function"
  s3_bucket = aws_s3_bucket.my_s3_bucket.bucket
  s3_key = "lambda.zip"
  handler      = "index.handler"
  runtime      = "python3.8"
  
  role = aws_iam_role.default.arn

}

resource "aws_iam_role" "default" {
  name = "iam-for-lambda-with-sns"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Sid    = "",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "sqs-policy"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
            "sqs:ListQueueTags",
          ],
          Resource = aws_sqs_queue.my_queue.arn,
        },
      ]
    })
  }
}





# Define the Step Functions state machine
resource "aws_sfn_state_machine" "my_state_machine" {
  name     = "my-state-machine"
  role_arn = aws_iam_role.my_role.arn
  definition = <<DEFINITION
{
  "Comment": "A simple Step Functions state machine",
  "StartAt": "PublishToSQS",
  "States": {
    "PublishToSQS": {
      "Type": "Task",
      "Resource": "arn:aws:states:::sqs:sendMessage",
      "Parameters": {
        "QueueUrl": "${aws_sqs_queue.my_queue.id}",
        "MessageBody": "Hello, SQS!"
      },
      "End": true
    }
  }
}
DEFINITION
}

# Define the IAM Role for Step Functions
resource "aws_iam_role" "my_role" {
  name = "step-functions-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "states.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}


# data "aws_sqs_queue" "my_data_queue" {
#   name = "my-queue"
# }



resource "aws_lambda_event_source_mapping" "example" {
  event_source_arn  = aws_sqs_queue.my_queue.arn
  function_name     = aws_lambda_function.my_lambda_function.arn
  
}




# # Define the IAM Role for Lambda execution
# resource "aws_iam_role" "lambda_execution_role" {
#   name = "lambda-execution-role"

#   assume_role_policy = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "lambda.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# POLICY
# }






