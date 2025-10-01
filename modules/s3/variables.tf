variable "bucket_name" {
  type = string
  default = "my-data-bucket"
}

variable "ingest_lambda_arn" {
  type = string
}

variable "ingest_lambda_name" {
  type = string
}
