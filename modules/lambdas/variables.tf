variable "lambda_role_arn" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "lambda_sg_id" {
  type = string
}

variable "aurora_endpoint" {
  type = string
}

variable "aurora_secret_arn" {
  type = string
}
