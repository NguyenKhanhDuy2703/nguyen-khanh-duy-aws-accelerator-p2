terraform {
  backend "s3" {
    bucket         = "dev-terraform-state-bucket-kduy"
    key            = "lab1-vpc-ec2-s3/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dev-terraform-state-lock"
    encrypt        = true
  }
}
