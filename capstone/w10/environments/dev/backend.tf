terraform {
  backend "s3" {
    bucket         = "capstone-w10-terraform-state"
    key            = "macie-sensitive-data/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "capstone-w10-terraform-locks"
    encrypt        = true
  }
}
