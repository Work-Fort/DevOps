# Remote state backend configuration
terraform {
  backend "s3" {
    bucket         = "workfort-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "workfort-terraform-locks"
  }
}
