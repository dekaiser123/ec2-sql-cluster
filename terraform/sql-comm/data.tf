data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "vpc_id" {
  id = var.vpc_id
}

data "aws_subnets" "subnet_ids" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_id.id]
  }
}

data "aws_subnet" "subnets" {
  for_each = toset(data.aws_subnets.subnet_ids.ids)
  id       = each.value
}

# data "aws_cloudformation_export" "codebuild-sg" {
#   name = var.cfn_exp_var
# }