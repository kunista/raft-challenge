output "lambda_role_arn" {
  value = aws_iam_role.lambda_exec.arn
}

output "aurora_s3_role_arn" {
  value = aws_iam_role.aurora_s3_role.arn
}
