import boto3
import os

rds = boto3.client("rds-data")

CLUSTER_ARN = os.environ["CLUSTER_ARN"]
SECRET_ARN = os.environ["SECRET_ARN"]
DB_NAME = os.environ["DB_NAME"]

def lambda_handler(event, context):
    sql = """
    SELECT COUNT(*) AS row_count,
           MAX(lastseen) AS last_transponder_seen_at,
           COUNT(DISTINCT icao24) AS count_of_unique_transponders,
           (SELECT estarrivalairport
            FROM flights
            GROUP BY estarrivalairport
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
    return {
        "row_count": record[0]["longValue"],
        "last_transponder_seen_at": record[1]["stringValue"],
        "count_of_unique_transponders": record[2]["longValue"],
        "most_popular_destination": record[3]["stringValue"]
    }
