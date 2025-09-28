output "cluster_arn" {
  value = module.aurora.cluster_arn
}

output "secret_arn" {
  value = module.aurora.secret_arn
}

output "api_lambda" {
  value = aws_lambda_function.query_lambda.function_name
}

output "ingest_lambda" {
  value = aws_lambda_function.ingest_lambda.function_name
}

output "bucket_name" {
  value = aws_s3_bucket.data_bucket.id
}
