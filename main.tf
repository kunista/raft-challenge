
provider "aws" {
  region = "us-east-1"
}

module "rds" {
  source = "./modules/rds"
}

module "s3" {
  source = "./modules/s3"
  bucket_name = "flight-data-bucket-example"
}

module "lambda" {
  source = "./modules/lambda"

  rds_endpoint       = module.rds.endpoint
  db_name            = module.rds.db_name
  db_user            = module.rds.db_user
  db_password        = module.rds.db_password
  s3_bucket_name     = module.s3.bucket_name
  s3_bucket_arn      = module.s3.bucket_arn
  vpc_security_group_ids = module.rds.security_group_ids
  vpc_subnet_ids     = module.rds.subnet_ids
}
