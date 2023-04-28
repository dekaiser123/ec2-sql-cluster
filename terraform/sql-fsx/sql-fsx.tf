
resource "aws_fsx_windows_file_system" "SqlCluster_FileShare" {

  deployment_type                 = var.fsx_deployment_type
  storage_type                    = var.fsx_storage_type
  storage_capacity                = var.fsx_storage_capacity
  throughput_capacity             = var.fsx_throughput_capacity
  automatic_backup_retention_days = var.fsx_backup_retention
  skip_final_backup               = var.fsx_skip_final_backup
  security_group_ids              = [var.sql_sg]
  subnet_ids                      = [var.fsx_subnet_id]
  #preferred_subnet_id            = tolist(data.aws_subnets.subnet_ids.ids)
  active_directory_id = data.aws_ssm_parameter.DirectoryId.value

  tags = merge(var.tags, tomap({ "Name" = join("-", [var.resource_prefix, var.env, "sql", "fileshare"]) }))
  # lifecycle {
  #   ignore_changes = [security_group_ids]
  # }
}
