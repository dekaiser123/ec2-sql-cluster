
resource "aws_network_interface" "sql-eni" {

  #subnet_id = element(tolist(data.aws_subnets.subnet_ids.ids), 2)
  subnet_id       = var.subnet_id #data.aws_subnet.subnet.id
  security_groups = var.sql_sg
  private_ips_count = lower(var.tags.Role) != "spare" ? 2 : null
  tags = {
    Name = join("-", [ local.sql_instance_name, "ENI" ])
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
