terraform {
  required_version = ">= 1.2.1"
  required_providers {
    aws    = {
      version = ">= 4.25"
    }
    random = {}
  }
  backend "s3" {}
}

provider "aws" {
  region = "<aws region>"
}
provider "random" {}
