# ─── IAM Role for Macie Classification Job ───────────────────────────────────
# Macie uses a service-linked role automatically, but we need permissions
# for the classification job to read from S3.

data "aws_iam_policy_document" "macie_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["macie.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "macie_classification" {
  name               = "${var.owner}-macie-classification-role"
  assume_role_policy = data.aws_iam_policy_document.macie_assume_role.json

  tags = {
    Name  = "${var.owner}-macie-classification-role"
    Owner = var.owner
  }
}

# Allow Macie to read objects from the target S3 bucket
data "aws_iam_policy_document" "macie_s3_read" {
  statement {
    sid    = "AllowMacieReadS3"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      var.bucket_arn,
      "${var.bucket_arn}/*",
    ]
  }

  statement {
    sid    = "AllowMacieDecryptS3"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["s3.*.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "macie_s3_read" {
  name   = "${var.owner}-macie-s3-read-policy"
  role   = aws_iam_role.macie_classification.id
  policy = data.aws_iam_policy_document.macie_s3_read.json
}
