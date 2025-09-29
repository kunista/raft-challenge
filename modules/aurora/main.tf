variable "db_name" {}
variable "master_username" {}
variable "master_password" {}
variable "subnet_ids" {
  type = list(string)
}
variable "vpc_security_group_id" {}

resource "aws_rds_cluster" "aurora" {
  engine               = "aurora-postgresql"
  engine_mode          = "provisioned"
  database_name        = var.db_name
  master_username      = var.master_username
  master_password      = var.master_password
  db_subnet_group_name = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [var.vpc_security_group_id]
  enable_http_endpoint = true
  skip_final_snapshot  = true
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
  engine             = "aurora-postgresql"
  publicly_accessible = true
}

resource "aws_db_subnet_group" "aurora" {
  name       = "aurora-subnet-group"
  subnet_ids = var.subnet_ids
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

output "secret_arn" {
  value = aws_secretsmanager_secret.aurora_secret.arn
}
