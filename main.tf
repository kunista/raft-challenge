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
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
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
      CLUSTER_ARN = module.aurora.cluster_arn
      SECRET_ARN  = module.aurora.secret_arn
      DB_NAME     = var.db_name
    }
  }
}

resource "aws_lambda_function_url" "summary_url" {
  function_name      = aws_lambda_function.query_lambda.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_function" "ingest_lambda" {
  filename         = "lambda/ingest_lambda.zip"
  timeout = 60
  function_name    = "IngestFlightData"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "ingest_lambda.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("lambda/ingest_lambda.zip")

  environment {
    variables = {
      CLUSTER_ARN = module.aurora.cluster_arn
      SECRET_ARN  = module.aurora.secret_arn
      DB_NAME     = var.db_name
    }
  }
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = var.bucket_name
  force_destroy = true
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


data "aws_secretsmanager_secret" "aurora_secret" {
  name = "aurora-db-credentials"  
}

resource "aws_iam_policy" "lambda_secrets_policy" {
  name = "lambda-secrets-access-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = data.aws_secretsmanager_secret.aurora_secret.arn
      },
      {
        Effect = "Allow",
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_secrets_policy.arn
}

resource "null_resource" "init_flights_table" {
  provisioner "local-exec" {
    command = <<EOT
aws rds-data execute-statement `
  --resource-arn ${module.aurora.cluster_arn} `
  --secret-arn ${module.aurora.secret_arn} `
  --database ${var.db_name} `
  --sql file://create_table.sql
EOT

    interpreter = ["PowerShell", "-Command"]
  }

  triggers = {
    always_run = timestamp()
  }
}