# 🚀 Raft Serverless Terraform Challenge  

This repository contains the solution to the **Raft Challenge**, where the goal is to build a **serverless data ingestion and API pipeline** in AWS using **Terraform, AWS Lambda, RDS, and S3**.  

The deployed infrastructure ingests data files from S3 into an RDS database, and exposes an API to query useful dataset statistics.  

Required dataset:  
[OpenSky Network Dataset](https://zenodo.org/record/5377831) 

To get the project running on your own AWS account run the deployment script.
bash scripts/deploy.sh

A diagram for the architecture can be found here:
infra-graph.png

Once deployment is complete, the API Gateway URL will be displayed in Terraform output.

curl https://<api-gateway-id>.execute-api.<region>.amazonaws.com/prod/summary



