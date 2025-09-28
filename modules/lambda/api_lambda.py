
import os
import psycopg2
import json

def lambda_handler(event, context):
    conn = psycopg2.connect(
        host=os.environ['DB_HOST'],
        dbname=os.environ['DB_NAME'],
        user=os.environ['DB_USER'],
        password=os.environ['DB_PASSWORD']
    )
    cur = conn.cursor()
    metrics = {}

    cur.execute("SELECT COUNT(*) FROM flights")
    metrics['row_count'] = cur.fetchone()[0]

    cur.execute("SELECT MAX(lastseen) FROM flights")
    metrics['last_transponder_seen_at'] = str(cur.fetchone()[0])

    cur.execute("SELECT estarrivalairport, COUNT(*) FROM flights GROUP BY estarrivalairport ORDER BY COUNT(*) DESC LIMIT 1")
    metrics['most_popular_destination'] = cur.fetchone()[0]

    cur.execute("SELECT COUNT(DISTINCT icao24) FROM flights")
    metrics['count_of_unique_transponders'] = cur.fetchone()[0]

    cur.close()
    conn.close()

    return {
        "statusCode": 200,
        "headers": { "Content-Type": "application/json" },
        "body": json.dumps(metrics)
    }
