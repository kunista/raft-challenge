import boto3
import os
import json

rds = boto3.client("rds-data")

CLUSTER_ARN = os.environ["CLUSTER_ARN"]
SECRET_ARN = os.environ["SECRET_ARN"]
DB_NAME = os.environ["DB_NAME"]

def lambda_handler(event, context):
    try:
        sql = """
        SELECT COUNT(*) AS row_count,
               MAX(lastseen) AS last_transponder_seen_at,
               COUNT(DISTINCT icao24) AS count_of_unique_transponders,
               (SELECT destination
                FROM flights
                GROUP BY destination
                ORDER BY COUNT(*) DESC
                LIMIT 1) AS most_popular_destination
        FROM flights
        """

        response = rds.execute_statement(
            secretArn=SECRET_ARN,
            resourceArn=CLUSTER_ARN,
            database=DB_NAME,
            sql=sql
        )

        record = response["records"][0]

        result = {
            "row_count": record[0].get("longValue"),
            "last_transponder_seen_at": record[1].get("stringValue"),
            "count_of_unique_transponders": record[2].get("longValue"),
            "most_popular_destination": record[3].get("stringValue")
        }

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"  # Optional CORS support
            },
            "body": json.dumps(result)
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e)
            })
        }
