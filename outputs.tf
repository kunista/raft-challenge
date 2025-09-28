output "db_cluster_arn" {
  value = module.aurora.cluster_arn
}

output "secret_arn" {
  value = module.aurora.secret_arn
}

output "lambda_function_name" {
  value = aws_lambda_function.query_lambda.function_name
}

output "ingest_lambda_name" {
  value = aws_lambda_function.ingest_lambda.function_name
}
