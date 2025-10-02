#!/bin/bash
set -e

echo "Cleaning old builds..."
rm -rf lambda/build/*

# Build api_lambda package
cd lambda
mkdir -p build/api_lambda
cp api_lambda.py requirements.txt build/api_lambda/
pip install --upgrade -r requirements.txt -t build/api_lambda/
cd build/api_lambda
zip -r ../../../lambda/api_lambda.zip . > /dev/null
cd ../../..

# Build ingest_lambda package
cd lambda
mkdir -p build/ingest_lambda
cp ingest_lambda.py requirements.txt build/ingest_lambda/
pip install --upgrade -r requirements.txt -t build/ingest_lambda/
cd build/ingest_lambda
zip -r ../../../lambda/ingest_lambda.zip . > /dev/null
cd ../../..

echo "Initializing Terraform"
terraform init

echo "Applying Terraform"
terraform apply -auto-approve

# ------------ Fetch Terraform outputs ------------
echo "Fetching Terraform outputs..."
S3_BUCKET_NAME=$(terraform output -raw bucket_name)
API_URL=$(terraform output -raw summary_function_url || true)

echo "S3 bucket: ${S3_BUCKET_NAME}"
[[ -n "$API_URL" ]] && echo "API Gateway URL: ${API_URL}"

# ------------ Download dataset ------------
# Dataset details
DATASET_URL="https://zenodo.org/records/5377831/files/flightlist_20190101_20190131.csv.gz?download=1"
DATASET_FILENAME="flightlist_20190101_20190131.csv"

echo "Downloading and extracting dataset..."
curl -L --fail "$DATASET_URL" | gunzip -c > "$DATASET_FILENAME"

echo "Dataset saved as $DATASET_FILENAME"

# ------------ Upload to S3 ------------
echo "Uploading dataset to S3..."
aws s3 cp "$DATASET_FILENAME" "s3://${S3_BUCKET_NAME}/$DATASET_FILENAME" -region us-west-1

echo "Uploaded to s3://${S3_BUCKET_NAME}/$DATASET_FILENAME"

# ------------ Final output ------------
echo
echo "Deployment and dataset upload complete!"
echo "S3 dataset location: s3://${S3_BUCKET_NAME}/$DATASET_FILENAME"
if [[ -n "$API_URL" ]]; then
  echo
  echo "Query the API summary endpoint:"
  echo "curl ${API_URL}/summary"
fi