data "aws_vpc" "vpc_id" {
  id = var.vpc_id
}

data "aws_iam_account_alias" "current" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

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

data "aws_availability_zone" "az" {
  for_each = data.aws_subnet.subnets
  name = each.value.availability_zone
}

data "aws_security_group" "fsx_sg" {
  count = local.fsx_sg_exist ? 1 : 0
  filter {
    name   = "group-name"
    values = [var.outbound_fsx_sg]
  }
}

data "aws_ec2_managed_prefix_list" "fsx_ept" {
  count = local.fsx_prefix_list_exist ? 1 : 0
  filter {
    name   = "prefix-list-name"
    values = [var.outbound_fsx_prefix_list]
  }
}

data "aws_ec2_managed_prefix_list" "all_list" {
  for_each = toset(var.outbound_all_prefix_list)
  filter {
    name   = "prefix-list-name"
    values = [each.value]
  }
}

data "aws_ec2_managed_prefix_list" "rdp_net" {
  filter {
    name   = "prefix-list-name"
    values = [var.inbound_rdp_prefix_list]
  }
}

# data "aws_cloudformation_export" "sns_topic_arn" {
#   name = var.sns_topic_arn
# }