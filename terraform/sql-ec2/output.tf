output "sqlserver_details" {
  description = "SQL details"
  value = [{
    server_name = local.sql_instance_name
    ip_address  = aws_instance.sqlserver.private_ip
    # admin_password_secret_name    = aws_ssm_parameter.sqlserver_secret.name
  }]
}

output "sqlserver_alerts" {
  description = "SQL instance map for cw alerts"
  value = {
    server_name = local.sql_instance_name
    id  = aws_instance.sqlserver.id
    alarms = local.sql_ec2_alerts_total
  }
}