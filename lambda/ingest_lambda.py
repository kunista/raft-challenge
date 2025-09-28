import boto3
import os
import csv
import io

s3 = boto3.client("s3")
rds = boto3.client("rds-data")

CLUSTER_ARN = os.environ["CLUSTER_ARN"]
SECRET_ARN = os.environ["SECRET_ARN"]
DB_NAME = os.environ["DB_NAME"]

def lambda_handler(event, context):
    record = event["Records"][0]
    bucket = record["s3"]["bucket"]["name"]
    key = record["s3"]["object"]["key"]

    response = s3.get_object(Bucket=bucket, Key=key)
    content = response["Body"].read().decode("utf-8")
    reader = csv.DictReader(io.StringIO(content))

    for row in reader:
        sql = """
        INSERT INTO flights (icao24, firstseen, lastseen, estarrivalairport)
        VALUES (:icao24, :firstseen, :lastseen, :estarrivalairport)
        """
        params = [
            {"name": "icao24", "value": {"stringValue": row["icao24"]}},
            {"name": "firstseen", "value": {"longValue": int(row["firstseen"])}},
            {"name": "lastseen", "value": {"longValue": int(row["lastseen"])}},
            {"name": "estarrivalairport", "value": {"stringValue": row.get("estarrivalairport", "")}},
        ]
        rds.execute_statement(
            secretArn=SECRET_ARN,
            resourceArn=CLUSTER_ARN,
            database=DB_NAME,
            sql=sql,
            parameters=params
        )

    return {
        "statusCode": 200,
        "body": f"File {key} ingested successfully"
    }
