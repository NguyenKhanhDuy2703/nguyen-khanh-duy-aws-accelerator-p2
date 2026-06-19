# ─── S3 Bucket to be scanned by Macie ────────────────────────────────────────
resource "aws_s3_bucket" "macie_target" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Name  = var.bucket_name
    Owner = var.owner
    Env   = var.env
  }
}

resource "aws_s3_bucket_versioning" "macie_target_versioning" {
  bucket = aws_s3_bucket.macie_target.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "macie_target_crypto" {
  bucket = aws_s3_bucket.macie_target.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "macie_target_pab" {
  bucket                  = aws_s3_bucket.macie_target.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── Upload sample sensitive test data ───────────────────────────────────────
# Macie will scan these files and generate findings

resource "aws_s3_object" "sample_pii_csv" {
  bucket  = aws_s3_bucket.macie_target.id
  key     = "test-data/pii-sample.csv"
  content = file("${path.module}/../../test-data/pii-sample.csv")

  tags = {
    DataType = "PII-Test"
    Owner    = var.owner
  }
}

resource "aws_s3_object" "sample_financial_csv" {
  bucket  = aws_s3_bucket.macie_target.id
  key     = "test-data/financial-sample.csv"
  content = file("${path.module}/../../test-data/financial-sample.csv")

  tags = {
    DataType = "Financial-Test"
    Owner    = var.owner
  }
}

resource "aws_s3_object" "sample_credentials_txt" {
  bucket  = aws_s3_bucket.macie_target.id
  key     = "test-data/credentials-sample.txt"
  content = file("${path.module}/../../test-data/credentials-sample.txt")

  tags = {
    DataType = "Credentials-Test"
    Owner    = var.owner
  }
}

resource "aws_s3_object" "sample_medical_json" {
  bucket  = aws_s3_bucket.macie_target.id
  key     = "test-data/medical-sample.json"
  content = file("${path.module}/../../test-data/medical-sample.json")

  tags = {
    DataType = "Medical-Test"
    Owner    = var.owner
  }
}
