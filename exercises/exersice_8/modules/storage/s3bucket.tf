resource "aws_s3_bucket" "s3_static_assets" {
    bucket = "${var.bucket_name}"
    tags = {
        Name = "${var.bucket_name}"
        Owner = var.owner
    }
}
resource "aws_s3_bucket_versioning" "s3_versioning" {
    bucket = aws_s3_bucket.s3_static_assets.id
    versioning_configuration {
        status = "Enabled"
    }
  
}
resource "aws_s3_account_public_access_block" "block_public_access" {
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
  
}
