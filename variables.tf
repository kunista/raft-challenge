variable "aws_region" {
  default = "us-east-1"
}

variable "db_name" {
  default = "flights"
}

variable "master_username" {
  default = "flights_admin"
}

variable "master_password" {
  description = "Master DB password"
  sensitive   = true
}

variable "bucket_name" {}

