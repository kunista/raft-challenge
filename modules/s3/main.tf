
variable "bucket_name" {}
resource "aws_s3_bucket" "flight_bucket" {
  bucket = var.bucket_name
}
output "bucket_name" {
  value = aws_s3_bucket.flight_bucket.bucket
}
output "bucket_arn" {
  value = aws_s3_bucket.flight_bucket.arn
}
