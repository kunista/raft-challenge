output "query_lambda_name" {
  value = aws_lambda_function.query_lambda.function_name
}

output "summary_url" {
  value = aws_lambda_function_url.summary_url.function_url
}

output "ingest_lambda_name" {
  value = aws_lambda_function.ingest_lambda.function_name
}

output "ingest_lambda_arn" {
  value = aws_lambda_function.ingest_lambda.arn
}
