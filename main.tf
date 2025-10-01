provider "aws" {
  region  = var.aws_region
  profile = "test"
}

# ----------------------------
# Availability zones (used by subnets)
# ----------------------------
data "aws_availability_zones" "available" {}

# ----------------------------
# Networking (Custom VPC)
# ----------------------------
resource "aws_vpc" "custom" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "custom-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom.id
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.custom.id
  cidr_block              = cidrsubnet(aws_vpc.custom.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-${count.index}" }
}

resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.custom.id
  cidr_block              = cidrsubnet(aws_vpc.custom.cidr_block, 8, count.index + 100)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = { Name = "private-subnet-${count.index}" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.custom.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.custom.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- Aurora DB Security Group (no inline ingress rules) ---
resource "aws_security_group" "aurora_sg" {
  name        = "aurora-db-sg"
  description = "Aurora DB security group"
  vpc_id      = aws_vpc.custom.id

  # Outbound allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aurora-db-sg"
  }
}

# --- Lambda Security Group (no inline ingress rules) ---
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-sg"
  description = "Lambda function security group"
  vpc_id      = aws_vpc.custom.id

  # Outbound allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lambda-sg"
  }
}

# --- Allow Lambda -> Aurora ---
resource "aws_security_group_rule" "aurora_from_lambda" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aurora_sg.id
  source_security_group_id = aws_security_group.lambda_sg.id
  description              = "Allow Lambda SG to connect to Aurora"
}

# ----------------------------
# Aurora Module
# ----------------------------
module "aurora" {
  source                  = "./modules/aurora"
  db_name                 = var.db_name
  master_username         = var.master_username
  master_password         = var.master_password
  vpc_security_group_id   = aws_security_group.aurora_sg.id
  subnet_ids              = aws_subnet.private[*].id
  aws_default_s3_role_arn = aws_iam_role.aurora_s3_role.arn
}


# ----------------------------
# IAM Roles & Attachments
# ----------------------------
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

# Lambda custom inline policy to allow ENI operations
resource "aws_iam_role_policy" "lambda_vpc_policy" {
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ],
      Resource = "*"
    }]
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
        Resource = module.aurora.secret_arn
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

# allow RDS to assume its role after module finishes creating resources
resource "aws_rds_cluster_role_association" "aurora_role_assoc" {
  db_cluster_identifier = module.aurora.cluster_id
  role_arn              = aws_iam_role.aurora_s3_role.arn
  depends_on            = [module.aurora]
}

# ----------------------------
# Query Lambda
# ----------------------------
resource "aws_lambda_function" "query_lambda" {
  filename         = "lambda/api_lambda.zip"
  timeout          = 300
  memory_size      = 1024
  function_name    = "QueryFlightMetrics"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "api_lambda.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("lambda/api_lambda.zip")

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # ensure SG exists before creating Lambdas
  depends_on = [aws_security_group.lambda_sg]

  environment {
    variables = {
      DB_HOST    = module.aurora.endpoint
      DB_NAME    = var.db_name
      SECRET_ARN = module.aurora.secret_arn
    }
  }
}

resource "aws_lambda_function_url" "summary_url" {
  function_name      = aws_lambda_function.query_lambda.function_name
  authorization_type = "NONE"
}

# ----------------------------
# Ingest Lambda
# ----------------------------
resource "aws_lambda_function" "ingest_lambda" {
  filename         = "lambda/ingest_lambda.zip"
  timeout          = 300
  memory_size      = 1024
  function_name    = "IngestFlightData"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "ingest_lambda.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("lambda/ingest_lambda.zip")

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  depends_on = [aws_security_group.lambda_sg]

  environment {
    variables = {
      DB_HOST    = module.aurora.endpoint
      DB_NAME    = var.db_name
      SECRET_ARN = module.aurora.secret_arn
    }
  }
}

# ----------------------------
# S3 + Notifications
# ----------------------------
resource "aws_s3_bucket" "data_bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_bucket.arn
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

# ----------------------------
# Lambda IAM Policies
# ----------------------------
# (lambda_vpc_policy & lambda_secrets_policy already declared above)
# ensure lambda_secrets_policy attachment exists (declared above)

# --- Step 1: Ensure database exists ---
resource "null_resource" "create_flights_db" {
  depends_on = [module.aurora]

  provisioner "local-exec" {
    command = <<EOT
      aws rds-data execute-statement \
        --resource-arn ${module.aurora.cluster_arn} \
        --secret-arn ${module.aurora.secret_arn} \
        --sql "CREATE DATABASE IF NOT EXISTS flights;"
    EOT
    interpreter = ["bash", "-c"]
  }
}

# --- Step 2: Create flights table ---
resource "null_resource" "init_flights_table" {
  depends_on = [null_resource.create_flights_db]

  provisioner "local-exec" {
    command = <<EOT
      aws rds-data execute-statement \
        --resource-arn ${module.aurora.cluster_arn} \
        --secret-arn ${module.aurora.secret_arn} \
        --database flights \
        --sql "CREATE TABLE IF NOT EXISTS flights.flights (
          id BIGINT AUTO_INCREMENT PRIMARY KEY,
          transponder_id VARCHAR(64) NOT NULL,
          origin VARCHAR(128),
          destination VARCHAR(128),
          seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );"
    EOT
    interpreter = ["bash", "-c"]
  }
}

# --- Step 3: Create flight_metrics summary table ---
resource "null_resource" "init_flight_metrics_table" {
  depends_on = [null_resource.init_flights_table]

  provisioner "local-exec" {
    command = <<EOT
      aws rds-data execute-statement \
        --resource-arn ${module.aurora.cluster_arn} \
        --secret-arn ${module.aurora.secret_arn} \
        --database flights \
        --sql "CREATE TABLE IF NOT EXISTS flights.flight_metrics (
          id INT PRIMARY KEY,
          row_count BIGINT,
          last_transponder_seen_at TIMESTAMP,
          count_of_unique_transponders INT,
          most_popular_destination VARCHAR(128),
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        );"
    EOT
    interpreter = ["bash", "-c"]
  }
}

# --- Step 4: Verification (SHOW TABLES) ---
resource "null_resource" "verify_tables" {
  depends_on = [
    null_resource.init_flights_table,
    null_resource.init_flight_metrics_table
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "Verifying tables in flights DB..."
      aws rds-data execute-statement \
        --resource-arn ${module.aurora.cluster_arn} \
        --secret-arn ${module.aurora.secret_arn} \
        --database flights \
        --sql "SHOW TABLES;"
    EOT
    interpreter = ["bash", "-c"]
  }
}



# --- Outputs ---
output "aurora_endpoint" {
  value = module.aurora.endpoint
}

output "aurora_secret" {
  value = module.aurora.secret_arn
}