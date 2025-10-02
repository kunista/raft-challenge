# Lambda execution role
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-rds-data-role-us-west-1"

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

# Lambda custom inline policy for ENIs
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

# Lambda secrets access policy
resource "aws_iam_policy" "lambda_secrets_policy" {
  name = "lambda-secrets-access-policy-us-west-1"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = var.aurora_secret_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_secrets_policy.arn
}

# Aurora S3 role
resource "aws_iam_role" "aurora_s3_role" {
  name = "aurora-s3-access-role-us-west-1"

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
  name        = "aurora-s3-access-policy-us-west-1"
  description = "Allow Aurora to read from S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"],
      Resource = [
        var.s3_bucket_arn,
        "${var.s3_bucket_arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "aurora_s3_policy_attach" {
  role       = aws_iam_role.aurora_s3_role.name
  policy_arn = aws_iam_policy.aurora_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "aurora_s3_policy_attach_lambda" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.aurora_s3_policy.arn
}

resource "aws_iam_policy" "terraform_full_vpc_teardown" {
  name        = "TerraformFullVpcTeardown-us-west-1"
  description = "Extra permissions so Terraform can destroy Lambdas, Aurora, ENIs, and EIPs cleanly"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Networking"
        Effect = "Allow"
        Action = [
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet",
          "ec2:DeleteInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:DeleteRouteTable",
          "ec2:DeleteRoute",
          "ec2:DeleteSecurityGroup",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DeleteNetworkAcl",
          "ec2:DeleteNetworkAclEntry",
          "ec2:DeleteNetworkInterface",
          "ec2:DetachNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DisassociateAddress",
          "ec2:ReleaseAddress",
          "ec2:DescribeAddresses"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSCluster"
        Effect = "Allow"
        Action = [
          "rds:DeleteDBCluster",
          "rds:DeleteDBInstance",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBClusters",
          "rds:DescribeDBInstances",
          "rds:ModifyDBSubnetGroup"
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaCleanup"
        Effect = "Allow"
        Action = [
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:ListFunctions",
          "ec2:DescribeNetworkInterfaces",   # Lambda ENIs
          "ec2:DetachNetworkInterface",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

