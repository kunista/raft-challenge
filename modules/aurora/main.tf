variable "db_name" {}
variable "master_username" {}
variable "master_password" {}
variable "subnet_ids" {
  type = list(string)
}
variable "vpc_security_group_id" {}

# New variable for the S3 import role ARN
variable "aws_default_s3_role_arn" {
  description = "IAM role ARN for Aurora to load data from S3"
  type        = string
}

resource "aws_db_subnet_group" "aurora" {
  name       = "aurora-subnet-group"
  subnet_ids = var.subnet_ids
}

# Create custom parameter group with aws_default_s3_role set
resource "aws_rds_cluster_parameter_group" "aurora_mysql_params" {
  name        = "aurora-mysql-custom-params"
  family      = "aurora-mysql8.0"  # or your specific engine family

  parameter {
    name  = "aws_default_s3_role"
    value = var.aws_default_s3_role_arn
  }
}

resource "aws_rds_cluster" "aurora" {
  engine                      = "aurora-mysql"
  engine_mode                 = "provisioned"
  database_name               = var.db_name
  master_username             = var.master_username
  master_password             = var.master_password
  db_subnet_group_name        = aws_db_subnet_group.aurora.name
  vpc_security_group_ids      = [var.vpc_security_group_id]
  enable_http_endpoint        = true
  skip_final_snapshot         = true
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora_mysql_params.name

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 2
  }
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  count              = 1
  identifier         = "aurora-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  publicly_accessible = true
}

resource "aws_secretsmanager_secret" "aurora_secret" {
  name = "aurora-db-credentials"
}

resource "aws_secretsmanager_secret_version" "secret_version" {
  secret_id     = aws_secretsmanager_secret.aurora_secret.id
  secret_string = jsonencode({
    username = var.master_username,
    password = var.master_password
  })
}

output "cluster_arn" {
  value = aws_rds_cluster.aurora.arn
}

output "endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

output "cluster_id" {
  value = aws_rds_cluster.aurora.id
}

output "secret_arn" {
  value = aws_secretsmanager_secret.aurora_secret.arn
}
