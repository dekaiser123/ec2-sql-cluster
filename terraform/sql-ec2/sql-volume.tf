/*
  convert the disk_config object arrays into maps (key-value pairs), where each key is e.g. "sqlnode01-data", and the value is the corresponding disk_config object e.g. "{ description = "data"; lun = 1; driveletter = "F"; size_gb = 1 }"
  Then use a for_each loop to create the actual disk objects.
  }
*/

locals {
  sqlserver_disk_config_map = {
    for d in var.sqlserver_disk_config : d.description => d
  }
}

resource "aws_ebs_volume" "sql-disk" {
  for_each = local.sqlserver_disk_config_map

  availability_zone = aws_instance.sqlserver.availability_zone
  size              = each.value.size_gb
  type              = each.value.type
  encrypted         = true
  iops              = each.value.iops
  throughput        = each.value.throughput
  tags = {
    #Name        = join("-", [var.resource_prefix, var.env, "sql",var.sql_node, each.key])
    Name = join("-", [ local.sql_instance_name, upper(each.value.description) ])
    DeviceName  = each.value.device_name
    DriveLetter = each.value.driveletter
    DriveName   = each.value.description
    Environment = var.tags.Environment
    Component   = var.tags.Component
  }
  # lifecycle {
  #   prevent_destroy = false
  #   ignore_changes = [
  #      tags,
  #   ]
  # }
}

resource "aws_volume_attachment" "sql-volume_attachment" {
  depends_on = [aws_instance.sqlserver, aws_ebs_volume.sql-disk]
  for_each   = local.sqlserver_disk_config_map

  instance_id  = aws_instance.sqlserver.id
  volume_id    = aws_ebs_volume.sql-disk[each.key].id
  device_name  = each.value.device_name
  force_detach = true
  skip_destroy = false
}
