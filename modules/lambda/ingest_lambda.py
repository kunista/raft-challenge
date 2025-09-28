
import os
import boto3
import psycopg2
import csv

def lambda_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key    = event['Records'][0]['s3']['object']['key']

    s3 = boto3.client('s3')
    response = s3.get_object(Bucket=bucket, Key=key)
    lines = response['Body'].read().decode('utf-8').splitlines()
    reader = csv.DictReader(lines)

    conn = psycopg2.connect(
        host=os.environ['DB_HOST'],
        dbname=os.environ['DB_NAME'],
        user=os.environ['DB_USER'],
        password=os.environ['DB_PASSWORD']
    )
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS flights (
            icao24 TEXT, firstseen TIMESTAMP, estdepartureairport TEXT,
            lastseen TIMESTAMP, estarrivalairport TEXT, callsign TEXT,
            estdepartureairporthorizdistance INT, estarrivalairporthorizdistance INT,
            estdepartureairportvertdistance INT, estarrivalairportvertdistance INT,
            departureairportcandidatescount INT, arrivalairportcandidatescount INT
        )
    """)
    for row in reader:
        cur.execute("""
            INSERT INTO flights VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, [
            row.get('icao24'), row.get('firstseen'), row.get('estdepartureairport'),
            row.get('lastseen'), row.get('estarrivalairport'), row.get('callsign'),
            row.get('estdepartureairporthorizdistance'), row.get('estarrivalairporthorizdistance'),
            row.get('estdepartureairportvertdistance'), row.get('estarrivalairportvertdistance'),
            row.get('departureairportcandidatescount'), row.get('arrivalairportcandidatescount')
        ])
    conn.commit()
    cur.close()
    conn.close()
    return {'statusCode': 200, 'body': 'Ingested'}
