variable "cluster_arn" {
  type = string
}

variable "secret_arn" {
  type = string
}

variable "db_name" {
  description = "Name of the database to initialize"
  type        = string
}

variable "master_username" {
  type        = string
  description = "The DB cluster master username"
}

