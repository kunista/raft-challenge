# Create DB if missing
resource "null_resource" "create_flights_db" {
  provisioner "local-exec" {
    command = <<EOT
      aws rds-data execute-statement \
        --resource-arn ${var.cluster_arn} \
        --secret-arn ${var.secret_arn} \
        --sql "CREATE DATABASE IF NOT EXISTS flights;"
    EOT
    interpreter = ["bash", "-c"]
  }
}

# Create flights table
resource "null_resource" "init_flights_table" {
  depends_on = [null_resource.create_flights_db]

  provisioner "local-exec" {
    command = <<EOT
      aws rds-data execute-statement \
        --resource-arn ${var.cluster_arn} \
        --secret-arn ${var.secret_arn} \
        --database flights \
        --sql "CREATE TABLE IF NOT EXISTS flights (
          callsign        VARCHAR(20),
          number          VARCHAR(20),
          icao24          VARCHAR(20),
          registration    VARCHAR(20),
          typecode        VARCHAR(20),
          origin          VARCHAR(4),
          destination     VARCHAR(4),
          firstseen       TIMESTAMP NOT NULL,
          lastseen        TIMESTAMP NOT NULL,
          day             DATE NOT NULL,
          latitude_1      DOUBLE,
          longitude_1     DOUBLE,
          altitude_1      DOUBLE,
          latitude_2      DOUBLE,
          longitude_2     DOUBLE,
          altitude_2      DOUBLE
        );"
    EOT
    interpreter = ["bash", "-c"]
  }
}

# Create flight_metrics table
resource "null_resource" "init_flight_metrics_table" {
  depends_on = [null_resource.init_flights_table]

  provisioner "local-exec" {
    command = <<EOT
      aws rds-data execute-statement \
        --resource-arn ${var.cluster_arn} \
        --secret-arn ${var.secret_arn} \
        --database flights \
        --sql "CREATE TABLE IF NOT EXISTS flight_metrics (
          id INT PRIMARY KEY DEFAULT 1,
          row_count BIGINT,
          last_transponder_seen_at DATETIME,
          count_of_unique_transponders BIGINT,
          most_popular_destination VARCHAR(50),
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        );"
    EOT
    interpreter = ["bash", "-c"]
  }
}

# Verification step
resource "null_resource" "verify_tables" {
  depends_on = [
    null_resource.init_flights_table,
    null_resource.init_flight_metrics_table
  ]

  provisioner "local-exec" {
    command = <<EOT
      aws rds-data execute-statement \
        --resource-arn ${var.cluster_arn} \
        --secret-arn ${var.secret_arn} \
        --database flights \
        --sql "SHOW TABLES;"
    EOT
    interpreter = ["bash", "-c"]
  }
}

resource "null_resource" "grant_aws_load_s3_access" {
  depends_on = [
    null_resource.init_flights_table,
    null_resource.init_flight_metrics_table
  ]
  provisioner "local-exec" {
    command = <<EOT
    aws rds-data execute-statement \
      --resource-arn ${var.cluster_arn} \
      --secret-arn ${var.secret_arn} \
      --database ${var.db_name} \
      --sql "GRANT AWS_LOAD_S3_ACCESS TO '${var.master_username}'@'%';"
    EOT
    interpreter = ["bash", "-c"]
  }

  triggers = {
    always_run = timestamp()
  }
}
