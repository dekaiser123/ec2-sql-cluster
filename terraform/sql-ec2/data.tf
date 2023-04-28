data "aws_iam_account_alias" "current" {}

data "aws_caller_identity" "current" {}

data "aws_vpc" "vpc_id" {
  id = var.vpc_id
}

data "aws_subnets" "subnet_ids" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_id.id]
  }
}

# data "aws_subnet" "subnet" {
#   availability_zone = var.availability_zone
# }

# data "aws_availability_zone" "az" {
#   name = var.availability_zone
# }

# data "aws_security_groups" "security_groups" {
#   filter {
#     name   = "group-name"
#     values = ["*Provider*"]
#   }
# }
