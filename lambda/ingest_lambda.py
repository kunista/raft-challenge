import os
import boto3
import csv
import io
from urllib.parse import unquote_plus

rds = boto3.client("rds-data")
s3 = boto3.client("s3")

CLUSTER_ARN = os.environ["CLUSTER_ARN"]
SECRET_ARN = os.environ["SECRET_ARN"]
DB_NAME = os.environ["DB_NAME"]

def string_or_null(value):
    if value is None or value == "":
        return {"isNull": True}
    return {"stringValue": str(value)}

def lambda_handler(event, context):
    try:
        record = event["Records"][0]
        bucket = record["s3"]["bucket"]["name"]
        key = unquote_plus(record["s3"]["object"]["key"])
    except Exception as e:
        return {"errorMessage": f"Malformed event structure: {str(e)}"}

    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        body = response["Body"].read().decode("utf-8")
        csv_reader = csv.DictReader(io.StringIO(body))

        for row in csv_reader:
            params = [
                string_or_null(row.get("callsign")),
                string_or_null(row.get("number")),
                string_or_null(row.get("icao24")),
                string_or_null(row.get("registration")),
                string_or_null(row.get("typecode")),
                string_or_null(row.get("origin")),
                string_or_null(row.get("destination")),
                string_or_null(row.get("firstseen")),
                string_or_null(row.get("lastseen")),
                string_or_null(row.get("day")),
                string_or_null(row.get("latitude_1")),
                string_or_null(row.get("longitude_1")),
                string_or_null(row.get("altitude_1")),
                string_or_null(row.get("latitude_2")),
                string_or_null(row.get("longitude_2")),
                string_or_null(row.get("altitude_2")),
            ]

            insert_sql = """
                INSERT INTO flights (
                    callsign, number, icao24, registration, typecode,
                    origin, destination, firstseen, lastseen, day,
                    latitude_1, longitude_1, altitude_1,
                    latitude_2, longitude_2, altitude_2
                ) VALUES (
                    :callsign, :number, :icao24, :registration, :typecode,
                    :origin, :destination, :firstseen::timestamptz, :lastseen::timestamptz, :day::date,
                    :latitude_1::double precision, :longitude_1::double precision, :altitude_1::double precision,
                    :latitude_2::double precision, :longitude_2::double precision, :altitude_2::double precision
                )
            """

            rds.execute_statement(
                resourceArn=CLUSTER_ARN,
                secretArn=SECRET_ARN,
                database=DB_NAME,
                sql=insert_sql,
                parameters=[
                    {"name": "callsign", "value": params[0]},
                    {"name": "number", "value": params[1]},
                    {"name": "icao24", "value": params[2]},
                    {"name": "registration", "value": params[3]},
                    {"name": "typecode", "value": params[4]},
                    {"name": "origin", "value": params[5]},
                    {"name": "destination", "value": params[6]},
                    {"name": "firstseen", "value": params[7]},
                    {"name": "lastseen", "value": params[8]},
                    {"name": "day", "value": params[9]},
                    {"name": "latitude_1", "value": params[10]},
                    {"name": "longitude_1", "value": params[11]},
                    {"name": "altitude_1", "value": params[12]},
                    {"name": "latitude_2", "value": params[13]},
                    {"name": "longitude_2", "value": params[14]},
                    {"name": "altitude_2", "value": params[15]},
                ],
            )
        return {"message": f"Successfully ingested {key} from bucket {bucket}"}
    except Exception as e:
        return {"errorMessage": str(e)}
