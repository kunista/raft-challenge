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
    from_port   = 3306
    to_port     = 3306
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

resource "aws_security_group" "lambda_sg" {
  name        = "lambda-sg"
  description = "Allow Lambda to connect to Aurora"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.aurora_sg.id]
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

  aws_default_s3_role_arn = aws_iam_role.aurora_s3_role.arn
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



resource "aws_rds_cluster_role_association" "aurora_role_assoc" {
  db_cluster_identifier = module.aurora.cluster_id
  role_arn              = aws_iam_role.aurora_s3_role.arn
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
  timeout       = 300
  memory_size   = 1024
  function_name    = "QueryFlightMetrics"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "api_lambda.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("lambda/api_lambda.zip")
  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  environment {
    variables = {
      DB_HOST     = module.aurora.endpoint
      DB_NAME     = var.db_name
      DB_USER     = jsondecode(data.aws_secretsmanager_secret_version.aurora_secret_version.secret_string)["username"]
      DB_PASSWORD = jsondecode(data.aws_secretsmanager_secret_version.aurora_secret_version.secret_string)["password"]
    }
  }
}

resource "aws_lambda_function_url" "summary_url" {
  function_name      = aws_lambda_function.query_lambda.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_function" "ingest_lambda" {
  filename         = "lambda/ingest_lambda.zip"
  timeout       = 300
  memory_size   = 1024
  function_name    = "IngestFlightData"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "ingest_lambda.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("lambda/ingest_lambda.zip")
  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  environment {
    variables = {
      DB_HOST     = module.aurora.endpoint
      DB_NAME     = var.db_name
      DB_USER     = jsondecode(data.aws_secretsmanager_secret_version.aurora_secret_version.secret_string)["username"]
      DB_PASSWORD = jsondecode(data.aws_secretsmanager_secret_version.aurora_secret_version.secret_string)["password"]
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

# Get the current version (with the actual secret string)
data "aws_secretsmanager_secret_version" "aurora_secret_version" {
  secret_id = data.aws_secretsmanager_secret.aurora_secret.id
}

resource "aws_iam_role_policy" "lambda_vpc_policy" {
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        Resource = "*"
      }
    ]
  })
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


resource "aws_iam_role" "aurora_s3_role" {
  name = "aurora-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "rds.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "aurora_s3_policy" {
  name        = "aurora-s3-access-policy"
  description = "Allow Aurora to read from S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket"
      ],
      Resource = [
        aws_s3_bucket.data_bucket.arn,
        "${aws_s3_bucket.data_bucket.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "aurora_s3_policy_attach_lambda" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.aurora_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "aurora_s3_policy_attach_cluster" {
  role       = aws_iam_role.aurora_s3_role.name
  policy_arn = aws_iam_policy.aurora_s3_policy.arn
}

# Create flights table
resource "null_resource" "init_flights_table" {
  provisioner "local-exec" {
    command = <<EOT
      aws rds-data execute-statement \
        --resource-arn ${module.aurora.cluster_arn} \
        --secret-arn ${module.aurora.secret_arn} \
        --database ${var.db_name} \
        --sql file://create_flights.sql
    EOT

    interpreter = ["bash", "-c"]
  }

  triggers = {
    always_run = timestamp()
  }
}

# Create flight_metrics table
resource "null_resource" "init_flight_metrics_table" {
  provisioner "local-exec" {
    command = <<EOT
      aws rds-data execute-statement \
        --resource-arn ${module.aurora.cluster_arn} \
        --secret-arn ${module.aurora.secret_arn} \
        --database ${var.db_name} \
        --sql file://create_flight_metrics.sql
    EOT

    interpreter = ["bash", "-c"]
  }

  depends_on = [null_resource.init_flights_table]

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "grant_aws_load_s3_access" {
  provisioner "local-exec" {
    command = <<EOT
    aws rds-data execute-statement \
      --resource-arn ${module.aurora.cluster_arn} \
      --secret-arn ${module.aurora.secret_arn} \
      --database ${var.db_name} \
      --sql "GRANT AWS_LOAD_S3_ACCESS TO '${var.master_username}'@'%';"
    EOT
    interpreter = ["bash", "-c"]
  }

  triggers = {
    always_run = timestamp()
  }
}