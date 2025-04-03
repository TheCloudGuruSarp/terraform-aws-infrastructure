terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-prod"
    key            = "prod/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks-prod"
    encrypt        = true
  }
}