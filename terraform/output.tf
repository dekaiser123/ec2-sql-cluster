output "account_details" {
  description = "AWS account details"
  value = [{
    account_id = data.aws_caller_identity.current.account_id
    account_alias = data.aws_iam_account_alias.current.account_alias
    region = data.aws_region.current.name
  }]
}

# output "sql_sns_topic" {
#   description = "sns topic arn"
#   value       = aws_cloudformation_stack.sns_topic.outputs["SnsTopicArn"]
# }

output "sql_comm_details" {
  description = "SQL common details"
  value = [{
    sql_sg_id            = aws_security_group.sql.id #module.sql-comm.sql_sg
    sql_instance_profile = module.sql-comm.sql_instance_profile
    # sql_keypair_id       = module.sql-comm.sql_keypair_id
    sql_s3_backup        = module.sql-comm.sqlbackup_s3
    sql_ec2_alerts_sns   = module.sql-comm.sns_topic_name
  }]
}

# output "sql_node_01_details" {
#   description = "SQL node 01 details"
#   value       = module.sql-01.sqlserver_details
# }

# output "sql_node_02_details" {
#   description = "SQL node 02 details"
#   value       = module.sql-02.sqlserver_details
# }

output Sqlserver_details {
  description = "Sqlserver details for downstream"
  # value = { for vm in keys(var.sql_nodes) : vm => module.sql-cluster[vm].sqlserver_details } #object
  value = [ for vm in keys(var.sql_nodes) : module.sql-cluster[vm].sqlserver_details ] #tuple
}

output instance_map {
  description = "instance_map"
  value = { for vm in keys(var.sql_nodes) : module.sql-cluster[vm].sqlserver_alerts.server_name => module.sql-cluster[vm].sqlserver_alerts.id } #object
}

# output alarm_map {
#   description = "alarm_map"
#   value = { for vm in keys(var.sql_nodes) : vm => module.sql-cluster[vm].sqlserver_alerts.alarms }
# }

# output data_id {
#   description = "data_id"
#   value = [ for v in data.aws_ec2_managed_prefix_list.all_list : v.id ]
# }

# output subnets_outerjoin {
#   description = "check which subnets not in list"
#   value = length(local.subnets_unused)
# }

output "sql_fsx_details" {
  description = "SQL fsx file-share dns"
  #value       = module.sql-fsx.witness_dns
  value = local.fsx_output
}

output ansible_sg_details {
  description = "ansible sg id"
  value = aws_security_group.ansible.id
}