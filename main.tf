provider "aws" {
  region  = var.aws_region
}

# ----------------------------
# Networking
# ----------------------------
module "networking" {
  source = "./modules/networking"
}

# ----------------------------
# Security Groups
# ----------------------------
module "security" {
  source   = "./modules/security"
  vpc_id   = module.networking.vpc_id
}

# ----------------------------
# IAM Roles
# ----------------------------
module "iam" {
  source = "./modules/iam"

  aurora_secret_arn = module.aurora.secret_arn
  s3_bucket_arn     = module.s3.bucket_arn
  s3_bucket_id      = module.s3.bucket_id
}

# ----------------------------
# Aurora DB
# ----------------------------
module "aurora" {
  source                  = "./modules/aurora"
  aurora_s3_role_arn = module.iam.aurora_s3_role_arn
  db_name                 = var.db_name
  master_username         = var.master_username
  master_password         = var.master_password
  vpc_security_group_id   = module.security.aurora_sg_id
  subnet_ids              = module.networking.private_subnets
  aws_default_s3_role_arn = module.iam.aurora_s3_role_arn
}

# ----------------------------
# Lambdas (Query + Ingest)
# ----------------------------
module "lambdas" {
  source = "./modules/lambdas"

  lambda_role_arn   = module.iam.lambda_role_arn
  subnet_ids        = module.networking.private_subnets
  lambda_sg_id      = module.security.lambda_sg_id
  aurora_endpoint   = module.aurora.endpoint
  aurora_secret_arn = module.aurora.secret_arn
}

# ----------------------------
# S3 + Notifications
# ----------------------------
module "s3" {
  source            = "./modules/s3"
  bucket_name       = var.bucket_name
  ingest_lambda_name = module.lambdas.ingest_lambda_name
  ingest_lambda_arn  = module.lambdas.ingest_lambda_arn
}


# ----------------------------
# DB Init (Bootstrap schema)
# ----------------------------
module "db_init" {
  source = "./modules/db_init"

  cluster_arn = module.aurora.cluster_arn
  secret_arn  = module.aurora.secret_arn
  db_name = var.db_name
  master_username = var.master_username
}

