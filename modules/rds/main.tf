
resource "aws_db_instance" "postgres" {
  identifier        = "flight-db"
  engine            = "postgres"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  username          = "postgres"
  password          = "FlightPass123!"
  db_name           = "flights"
  publicly_accessible = true
  skip_final_snapshot = true
}
output "endpoint" {
  value = aws_db_instance.postgres.address
}
output "db_name" {
  value = aws_db_instance.postgres.db_name
}
output "db_user" {
  value = aws_db_instance.postgres.username
}
output "db_password" {
  value = aws_db_instance.postgres.password
}
