locals {
  # schedule_key   = var.env=="dev" ? "Schedule" : ""
  tags = {
    "Environment" = lower(var.env)
    "Prefix" = lower(var.resource_prefix)
  }

  vpc_cidr_block = [ for s in data.aws_subnet.subnets : s.cidr_block ]
  sql_tags = { for k, v in var.sql_tags : k => v if k != "FsxWitness" }

  fsx_sg_exist = var.outbound_fsx_sg != null ? true : false
  fsx_prefix_list_exist = var.outbound_fsx_prefix_list != null ? true : false
  provision_fsx = !local.fsx_prefix_list_exist && !local.fsx_sg_exist ? true : false

  single_node = length(var.sql_nodes) == 1 ? "standalone" : null
  fsx_dns = local.provision_fsx ? module.sql-fsx[0].witness_dns : var.sql_tags.FsxWitness
  fsx_output = coalesce(local.single_node, local.fsx_dns)

  subnets_unused = setsubtract(data.aws_subnets.subnet_ids.ids, [ for vm in keys(var.sql_nodes) : var.sql_nodes[vm].subnet_id ])
  az_suffix = { for s in toset(data.aws_subnets.subnet_ids.ids) : s => data.aws_availability_zone.az[s].name_suffix }
}

module "sql-comm" {
  source          = "./sql-comm"
  resource_prefix = var.resource_prefix
  vpc_id          = data.aws_vpc.vpc_id.id
  env             = var.env
  # account_id      = data.aws_caller_identity.current.account_id
  # region          = data.aws_region.current.name
  # cfn_exp_var     = "codebuild-docker-image-PackerSecurityGroupId"
  # subnet_ids      = tolist(data.aws_subnets.subnet_ids.ids)

  s3bucket_resources = var.s3bucket_resources
  s3_access_logging_bucket = var.s3_access_logging_bucket
  sns_subscription_email = var.sns_subscription_email

  tags = merge(var.tags, local.tags)
}

module "sql-fsx" {
  source                  = "./sql-fsx"
  count                   = local.provision_fsx ? 1 : 0
  resource_prefix         = var.resource_prefix
  env                     = var.env
  fsx_subnet_id           = length(local.subnets_unused) > 0 ? element(tolist(local.subnets_unused), 0) : element(tolist(data.aws_subnets.subnet_ids.ids), 0)
  fsx_deployment_type     = "SINGLE_AZ_1"
  fsx_storage_type        = "SSD"
  fsx_storage_capacity    = 32
  fsx_throughput_capacity = 8
  fsx_backup_retention    = 0
  fsx_skip_final_backup   = true
  sql_sg                  = aws_security_group.sql.id

  tags = merge(var.tags, local.tags)
  depends_on = [aws_security_group.sql]
}

module "sql-cluster" {
  source                = "./sql-ec2"
  for_each              = var.sql_nodes
  sql_node              = each.key
  subnet_id             = each.value.subnet_id #element(tolist(data.aws_subnets.subnet_ids.ids), 1)
  az_suffix             = lookup(local.az_suffix, each.value.subnet_id, null) #join("", [data.aws_region.current.name, each.value.az_suffix])
  resource_prefix       = var.resource_prefix
  env                   = var.env
  name_prefix           = var.name_prefix
  # account_id            = data.aws_caller_identity.current.account_id
  vpc_id                = data.aws_vpc.vpc_id.id
  ami_id                = var.sqlserver_ami
  instance_type         = var.sqlserver_instance_type
  pg_name               = var.pg_name
  volume_type           = var.sqlserver_volume_type
  volume_size           = var.sqlserver_volume_size
  volume_iops           = var.sqlserver_volume_iops
  volume_throughput     = var.sqlserver_volume_throughput
  sqlserver_disk_config = var.sqlserver_disk_config
  gitrepo               = var.gitrepo
  sql_webhookbucket     = split("arn:aws:s3:::", var.s3bucket_resources[0])[1]
  sql_sg                = [aws_security_group.sql.id]
  # sql-keypair           = module.sql-comm.sql_keypair_id
  # sql-privpem           = module.sql-comm.sql_priv_pem
  sql-instanceprofile   = module.sql-comm.sql_instance_profile
  sns_topic             = module.sql-comm.sns_topic_arn #data.aws_cloudformation_export.sns_topic_arn.value
  
  #tags = merge(var.tags,tomap({ "FsxWitness" = module.sql-fsx.witness_dns, "BackupBucket" = module.sql-comm.sqlbackup_s3, }), var.sql_tags)
  tags = merge(var.tags, tomap({ "FsxWitness" = local.fsx_output, "BackupBucket" = module.sql-comm.sqlbackup_s3, }), local.tags, local.sql_tags, each.value.tags)
  depends_on = [module.sql-comm, aws_security_group.sql]
}

# module "sql-02" {
#   source                = "./sql-ec2"
#   sql_node              = "02"
#   subnet_id             = element(tolist(data.aws_subnets.subnet_ids.ids), 0)
#   availability_zone     = join("", [data.aws_region.current.name, "a"])
#   resource_prefix       = var.resource_prefix
#   env                   = var.env
#   account_id            = data.aws_caller_identity.current.account_id
#   vpc_id                = data.aws_vpc.vpc_id.id
#   ami_id                = var.sqlserver_ami
#   instance_type         = var.sqlserver_instance_type
#   volume_type           = var.sqlserver_volume_type
#   volume_size           = var.sqlserver_volume_size
#   volume_iops           = var.sqlserver_volume_iops
#   volume_throughput     = var.sqlserver_volume_throughput
#   sqlserver_disk_config = var.sqlserver_disk_config
#   sql_sg                = module.sql-comm.sql_sg
#   sql-keypair           = module.sql-comm.sql_keypair_id
#   sql-privpem           = module.sql-comm.sql_priv_pem
#   sql-instanceprofile   = module.sql-comm.sql_instance_profile
#   sns_topic             = data.aws_cloudformation_export.sns_topic_arn.value

#   tags = merge(var.tags,tomap({ "FSxWitness" = var.fsx_dns, "BackupBucket" = module.sql-comm.sqlbackup_s3, (local.schedule_key) = var.env=="dev" ? var.schedule_tags.db02 : "", "Role" = "Secondary", }), var.sql_tags)
# }