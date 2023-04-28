variable "resource_prefix" {
  description = "prefix name to use on the resource to be deployed. (will be suffixed with a random number)"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "env" {}

# variable "cfn_exp_var" {}
variable "tags" {}

variable "s3bucket_resources" {}
variable "s3_access_logging_bucket" {}
variable "sns_subscription_email" {}