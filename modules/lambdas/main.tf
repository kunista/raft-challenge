resource "aws_lambda_function" "query_lambda" {
  filename         = "lambda/api_lambda.zip"
  timeout          = 300
  memory_size      = 1024
  function_name    = "QueryFlightMetrics"
  role             = var.lambda_role_arn
  handler          = "api_lambda.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("lambda/api_lambda.zip")

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      DB_HOST    = var.aurora_endpoint
      DB_NAME    = "flights"
      SECRET_ARN = var.aurora_secret_arn
    }
  }
}

resource "aws_lambda_function_url" "summary_url" {
  function_name      = aws_lambda_function.query_lambda.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_function" "ingest_lambda" {
  filename         = "lambda/ingest_lambda.zip"
  timeout          = 300
  memory_size      = 1024
  function_name    = "IngestFlightData"
  role             = var.lambda_role_arn
  handler          = "ingest_lambda.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("lambda/ingest_lambda.zip")

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  environment {
    variables = {
      DB_HOST    = var.aurora_endpoint
      DB_NAME    = "flights"
      SECRET_ARN = var.aurora_secret_arn
    }
  }
}
