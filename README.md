# Raft Serverless Terraform Challenge  

This repository contains the solution to the **Raft Challenge**, where the objective is to build a **serverless data ingestion and API pipeline** in AWS using **Terraform, AWS Lambda, Amazon RDS, and Amazon S3**. This repo has been tested on a windows OS with Git Bash installed. You would need to make minor tweaks to get it to work on Linux if you plan to test it in your production environment(modules\db_init\main.tf).

---

## Overview  

The deployed infrastructure will:  
- Ingest data files from **S3** into an **RDS** database  
- Expose an **API Gateway endpoint** backed by Lambda  
- Provide useful **dataset statistics** through the API  

---

## Dataset  

Required dataset:  
[OpenSky Network Dataset](https://zenodo.org/record/5377831)  

## Deployment  

Run the following script to deploy everything on your own AWS account:  

```bash
bash scripts/deploy.sh
```

You would need to provide unique s3 bucket name and password.

A diagram of the deployed architecture is included:

```
infra-graph.png
```

Once deployment is complete, the API Gateway URL will be displayed in the Terraform output. You would need to wait 2-3 minutes for the db population before you can access summary API .

Example Request

```bash
curl https://<api-gateway-id>.execute-api.<region>.amazonaws.com/prod/summary
```


