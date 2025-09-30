import os
import json
import traceback
import pymysql

def lambda_handler(event, context):
    print("🔔 Lambda triggered with event:", json.dumps(event)[:500])  # limit size

    # Extract S3 bucket + key from event
    try:
        record = event["Records"][0]
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]
        print(f"📦 Processing file: s3://{bucket}/{key}")
    except Exception as e:
        print("❌ Failed to extract S3 info:", e)
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Invalid S3 event", "details": str(e)})
        }

    # DB connection details from environment
    DB_HOST = os.environ["DB_HOST"]
    DB_NAME = os.environ["DB_NAME"]
    DB_USER = os.environ["DB_USER"]
    DB_PASSWORD = os.environ["DB_PASSWORD"]

    conn = None
    cursor = None

    try:
        print("🔌 Connecting to Aurora...")
        conn = pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            connect_timeout=10,
            autocommit=False  # transaction handling
        )
        cursor = conn.cursor()
        print("✅ Aurora connection established")

        # Step 1: Build the LOAD DATA FROM S3 query
        load_sql = f"""
        LOAD DATA FROM S3 's3://{bucket}/{key}'
        INTO TABLE flights
        FIELDS TERMINATED BY ','
        ENCLOSED BY '"'
        LINES TERMINATED BY '\\n'
        IGNORE 1 LINES
        (
            callsign, number, icao24, registration, typecode,
            origin, destination, @firstseen, @lastseen, @day,
            @latitude_1, @longitude_1, @altitude_1,
            @latitude_2, @longitude_2, @altitude_2
        )
        SET
            firstseen    = STR_TO_DATE(LEFT(@firstseen, 19), '%Y-%m-%d %H:%i:%s'),
            lastseen     = STR_TO_DATE(LEFT(@lastseen, 19), '%Y-%m-%d %H:%i:%s'),
            day          = STR_TO_DATE(LEFT(@day, 10), '%Y-%m-%d'),
            latitude_1   = CAST(NULLIF(@latitude_1, '') AS DOUBLE),
            longitude_1  = CAST(NULLIF(@longitude_1, '') AS DOUBLE),
            altitude_1   = CAST(NULLIF(@altitude_1, '') AS DOUBLE),
            latitude_2   = CAST(NULLIF(@latitude_2, '') AS DOUBLE),
            longitude_2  = CAST(NULLIF(@longitude_2, '') AS DOUBLE),
            altitude_2   = CAST(NULLIF(@altitude_2, '') AS DOUBLE)
        ;
        """

        print("▶️ Running LOAD DATA FROM S3...")
        cursor.execute(load_sql)
        print("✅ LOAD DATA completed")

        # Step 2: Refresh summary table
        refresh_sql = """
        REPLACE INTO flight_metrics
        SELECT
            1 AS id,
            COUNT(*) AS row_count,
            MAX(lastseen) AS last_transponder_seen_at,
            COUNT(DISTINCT icao24) AS count_of_unique_transponders,
            (
                SELECT destination
                FROM flights
                GROUP BY destination
                ORDER BY COUNT(*) DESC
                LIMIT 1
            ) AS most_popular_destination,
            NOW() AS updated_at
        FROM flights;
        """

        print("▶️ Refreshing flight_metrics summary table...")
        cursor.execute(refresh_sql)
        print("✅ Summary table refreshed")

        # Commit both operations
        print("💾 Committing transaction...")
        conn.commit()
        print("✅ Transaction committed successfully")

        return {
            "statusCode": 200,
            "body": f"Loaded s3://{bucket}/{key} into flights and refreshed summary table"
        }

    except Exception as e:
        if conn:
            conn.rollback()
            print("↩️ Transaction rolled back due to error")
        tb = traceback.format_exc()
        print("❌ Exception occurred:", e)
        print(tb)
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": "Failed to load and refresh metrics",
                "exception": str(e),
                "traceback": tb
            })
        }

    finally:
        if cursor:
            cursor.close()
            print("🔒 Cursor closed")
        if conn:
            conn.close()
            print("🔒 DB connection closed")
