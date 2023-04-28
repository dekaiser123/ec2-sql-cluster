locals {
  sql_instance_name = upper(join("", [var.name_prefix, substr(var.resource_prefix, 0, 6), substr(var.env, 0, 1), var.tags.Component, var.sql_node, var.az_suffix]))
}

# data "template_file" "sql-userdata" {
#   template = file("${path.root}/scripts/sql_userdata.ps1")
#   vars = {
#     computer_name = local.sql_instance_name
#     environment = var.tags.Environment
#     role = var.tags.Role
#     accountid = var.account_id
#   }
# }

# data "template_cloudinit_config" "config" {
#   gzip          = false
#   base64_encode = false

#   part {
#     filename     = "sql_userdata.ps1"
#     content_type = "text/cloud-config"
#     content      = data.template_file.sql-userdata.rendered
#   }
# }

resource "aws_instance" "sqlserver" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  # key_name             = var.sql-keypair
  iam_instance_profile = var.sql-instanceprofile
  placement_group      = var.pg_name
  disable_api_termination = true
  monitoring           = true
  # get_password_data    = true #only enable when key_name is assigned otherwise tf can't get the local admin pw and build fails
  ebs_optimized        = true
  user_data            = base64encode(templatefile("${path.module}/sql-userdata.ps1", {
    computer_name = local.sql_instance_name
    environment = var.tags.Environment
    role = var.tags.Role
    accountid = data.aws_caller_identity.current.account_id
    s3webhookbucket = var.sql_webhookbucket
    accountalias = data.aws_iam_account_alias.current.account_alias
    repository = var.gitrepo
  }))

  metadata_options {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 4
      instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = var.volume_type
    volume_size           = var.volume_size
    iops                  = var.volume_iops
    throughput            = var.volume_throughput
    delete_on_termination = true
    tags = {
      Name = join("-", [ local.sql_instance_name, "WINDOWS" ])
      DeviceName  = "/dev/sda1"
      DriveLetter = "C"
      DriveName   = "WINDOWS"
      Environment = var.tags.Environment
      Component   = var.tags.Component
    } 
  }

  network_interface {
    network_interface_id = aws_network_interface.sql-eni.id
    device_index         = 0
  }

  tags = merge(var.tags, tomap({ "Name" = local.sql_instance_name, }))

  lifecycle {
    ignore_changes = [
      user_data
    ]
  }
}
