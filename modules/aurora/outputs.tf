output "cluster_arn" {
  value = aws_rds_cluster.aurora.arn
}

output "secret_arn" {
  value = aws_secretsmanager_secret.aurora_secret.arn
}

output "instance_id" {
  value = aws_rds_cluster_instance.aurora_instance[0].id
}
