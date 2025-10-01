output "aurora_endpoint" {
  value = module.aurora.endpoint
}

output "aurora_secret" {
  value = module.aurora.secret_arn
}

output "api_lambda" {
  value = module.lambdas.query_lambda_name
}

output "summary_function_url" {
  value = module.lambdas.summary_url
}

output "ingest_lambda" {
  value = module.lambdas.ingest_lambda_name
}

output "bucket_name" {
  value = module.s3.bucket_name
}

output "cluster_arn" {
  value = module.aurora.cluster_arn
}

output "secret_arn" {
  value = module.aurora.secret_arn
}

