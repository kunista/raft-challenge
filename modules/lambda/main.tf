
variable "rds_endpoint" {}
variable "db_name" {}
variable "db_user" {}
variable "db_password" {}
variable "s3_bucket_name" {}
variable "s3_bucket_arn" {}
variable "vpc_security_group_ids" {}
variable "vpc_subnet_ids" {}

resource "aws_lambda_function" "ingest_lambda" {
  filename         = "ingest_lambda.zip"
  function_name    = "IngestFlightData"
  role             = "arn:aws:iam::123456789012:role/lambda_exec_role"
  handler          = "ingest_lambda.lambda_handler"
  runtime          = "python3.10"
  environment {
    variables = {
      DB_HOST     = var.rds_endpoint
      DB_NAME     = var.db_name
      DB_USER     = var.db_user
      DB_PASSWORD = var.db_password
    }
  }
}

resource "aws_lambda_function" "api_lambda" {
  filename         = "api_lambda.zip"
  function_name    = "FlightMetricsAPI"
  role             = "arn:aws:iam::123456789012:role/lambda_exec_role"
  handler          = "api_lambda.lambda_handler"
  runtime          = "python3.10"
  environment {
    variables = {
      DB_HOST     = var.rds_endpoint
      DB_NAME     = var.db_name
      DB_USER     = var.db_user
      DB_PASSWORD = var.db_password
    }
  }
}
