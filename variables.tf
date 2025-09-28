variable "aws_region" {
  default = "us-east-1"
}

variable "db_name" {
  default = "flights"
}

variable "master_username" {
  default = "admin"
}

variable "master_password" {
  description = "Master DB password"
  sensitive   = true
}

variable "cluster_arn" {}

variable "secret_arn" {}

variable "bucket_name" {}
