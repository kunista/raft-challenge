#!/bin/bash
set -e

echo "Packaging Lambda functions"
cd lambda
zip -r ../lambda/api_lambda.zip api_lambda.py requirements.txt > /dev/null
zip -r ../lambda/ingest_lambda.zip ingest_lambda.py requirements.txt > /dev/null
cd ..

echo "Initializing Terraform"
terraform init

echo "Applying Terraform"
terraform apply -auto-approve -var="bucket_name=my-raft-bucket-20250928" -var="master_password=Kunista3484!"

echo "Done. Upload CSV to the S3 bucket using:"
echo "aws s3 cp your_data.csv s3://$(terraform output -raw bucket_name)/your_data.csv"
