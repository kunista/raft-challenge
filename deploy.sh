#!/bin/bash
set -e

echo "Initializing Terraform..."
terraform init

echo "Applying Terraform..."
terraform apply -auto-approve

echo "Packaging Lambda functions..."
cd modules/lambda
zip ingest_lambda.zip ingest_lambda.py
zip api_lambda.zip api_lambda.py
cd ../..

echo "Reapplying Terraform with packaged Lambda..."
terraform apply -auto-approve

echo "Uploading dataset to S3..."
bucket=$(terraform output -raw bucket_name)
aws s3 cp dataset/flights.csv s3://$bucket/flights.csv

echo "Deployment complete."
