provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "aurora_sg" {
  name   = "aurora-db-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "aurora" {
  source                = "./modules/aurora"
  db_name               = var.db_name
  master_username       = var.master_username
  master_password       = var.master_password
  vpc_security_group_id = aws_security_group.aurora_sg.id
  subnet_ids            = data.aws_subnets.default.ids
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-rds-data-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "rds_data_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSDataFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_read_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_lambda_function" "query_lambda" {
  filename         = "lambda/api_lambda.zip"
  function_name    = "QueryFlightMetrics"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "api_lambda.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("lambda/api_lambda.zip")

  environment {
    variables = {
      CLUSTER_ARN = var.cluster_arn
      SECRET_ARN  = var.secret_arn
      DB_NAME     = var.db_name
    }
  }
}

resource "aws_lambda_function" "ingest_lambda" {
  filename         = "lambda/ingest_lambda.zip"
  function_name    = "IngestFlightData"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "ingest_lambda.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("lambda/ingest_lambda.zip")

  environment {
    variables = {
      CLUSTER_ARN = var.cluster_arn
      SECRET_ARN  = var.secret_arn
      DB_NAME     = var.db_name
    }
  }
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = var.bucket_name
  acl    = "private"
}

resource "aws_s3_bucket_notification" "s3_event" {
  bucket = aws_s3_bucket.data_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.ingest_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_bucket.arn
}
