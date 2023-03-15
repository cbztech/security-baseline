terraform {
  backend "s3" {
    bucket = "stacksec-infra"
    key    = "terraform/security-baseline"
    region = "us-west-2"
  }
}
