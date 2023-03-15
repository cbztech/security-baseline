terraform {
  backend "s3" {
    bucket = "stack-security-baseline"
    key    = "terraform/security-baseline"
    region = "us-west-2"
  }
}
