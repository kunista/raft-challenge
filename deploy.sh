#!/bin/bash
set -e

# Build api_lambda package
cd lambda
mkdir -p build/api_lambda
cp api_lambda.py requirements.txt build/api_lambda/
pip install -r requirements.txt -t build/api_lambda/
cd build/api_lambda
zip -r ../../../lambda/api_lambda.zip . > /dev/null
cd ../../..

# Build ingest_lambda package
cd lambda
mkdir -p build/ingest_lambda
cp ingest_lambda.py requirements.txt build/ingest_lambda/
pip install -r requirements.txt -t build/ingest_lambda/
cd build/ingest_lambda
zip -r ../../../lambda/ingest_lambda.zip . > /dev/null
cd ../../..

echo "Initializing Terraform"
terraform init

echo "Applying Terraform"
terraform apply -auto-approve \
  -var="bucket_name=my-raft-bucket-20250928" \
  -var="master_password=Kunista3484!"

echo "Done. Upload CSV to the S3 bucket using:"
echo "aws s3 cp your_data.csv s3://$(terraform output -raw bucket_name)/your_data.csv"
