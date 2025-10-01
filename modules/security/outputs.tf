output "aurora_sg_id" {
  value = aws_security_group.aurora_sg.id
}

output "lambda_sg_id" {
  value = aws_security_group.lambda_sg.id
}
