import os
import json
import pymysql

def lambda_handler(event, context):
    if event is None:
        event = {}
    elif isinstance(event, str):
        try:
            event = json.loads(event) or {}
        except json.JSONDecodeError:
            event = {}

    DB_HOST = os.environ.get("DB_HOST")
    DB_NAME = os.environ.get("DB_NAME")
    DB_USER = os.environ.get("DB_USER")
    DB_PASSWORD = os.environ.get("DB_PASSWORD")

    try:
        conn = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            connect_timeout=10,
            cursorclass=pymysql.cursors.DictCursor
        )

        # Query the pre-aggregated summary row (id=1 is always the current snapshot)
        sql = """
        SELECT row_count,
               last_transponder_seen_at,
               count_of_unique_transponders,
               most_popular_destination,
               updated_at
        FROM flight_metrics
        WHERE id = 1
        """

        with conn.cursor() as cursor:
            cursor.execute(sql)
            record = cursor.fetchone()

        conn.close()

        if not record:
            return {
                "statusCode": 404,
                "body": json.dumps({"error": "No summary data available. Refresh job may not have run yet."})
            }

        result = {
            "row_count": int(record["row_count"]),
            "last_transponder_seen_at": str(record["last_transponder_seen_at"]),
            "count_of_unique_transponders": int(record["count_of_unique_transponders"]),
            "most_popular_destination": record["most_popular_destination"],
            "last_updated": str(record["updated_at"])
        }

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps(result)
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
