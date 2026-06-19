# ─── Enable Amazon Macie ─────────────────────────────────────────────────────
resource "aws_macie2_account" "this" {
  status                       = "ENABLED"
  finding_publishing_frequency = var.finding_publishing_frequency
}

# ─── Classification Job — One-time scan of the target bucket ─────────────────
resource "aws_macie2_classification_job" "scan_sensitive_data" {
  depends_on = [aws_macie2_account.this]

  name       = "${var.owner}-sensitive-data-scan"
  job_type   = var.job_type
  job_status = "RUNNING"

  s3_job_definition {
    bucket_definitions {
      account_id = var.aws_account_id
      buckets    = [var.target_bucket_name]
    }

    scoping {
      includes {
        and {
          simple_scope_term {
            comparator = "EQ"
            key        = "OBJECT_EXTENSION"
            values     = ["csv", "txt", "json", "pdf", "doc", "docx", "xls", "xlsx"]
          }
        }
      }
    }
  }

  tags = {
    Name  = "${var.owner}-sensitive-data-scan"
    Owner = var.owner
  }
}
