#!/bin/bash
set -e

echo "Initializing Terraform"
terraform init

echo "Packaging Lambda functions"

cd lambda
zip -r ../lambda/api_lambda.zip api_lambda.py requirements.txt
zip -r ../lambda/ingest_lambda.zip ingest_lambda.py requirements.txt
cd ..

echo "Applying Terraform plan"
terraform apply -auto-approve

echo "Upload your dataset to the S3 bucket after deployment using:"
echo "aws s3 cp your_dataset.csv s3://${bucket_name}/your_dataset.csv"
