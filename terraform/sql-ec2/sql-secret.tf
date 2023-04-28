# resource "aws_secretsmanager_secret" "sql-secret" {

#   name                    = join("/", ["", var.resource_prefix, var.env, "sql", var.sql_node, "Administrator"])
#   description             = "windows Administrator Password"
#   recovery_window_in_days = 0
#   tags                    = merge(var.tags, tomap({ "Name" = join("/", ["", var.resource_prefix, var.env, "sql", var.sql_node, "Administrator"]) }))
# }

# resource "aws_secretsmanager_secret_version" "sql_secret_value" {

#   secret_id     = aws_secretsmanager_secret.sql-secret.id
#   secret_string = rsadecrypt(aws_instance.sqlserver.password_data, join("", [var.sql-privpem]))
# }

### Added SSM Parameter

# resource "aws_ssm_parameter" "sqlserver_secret" {

#   name        = join("/", ["", var.resource_prefix, var.env, "sql", var.sql_node, "Administrator"])
#   description = "SQL windows Administrator_Password "
#   type        = "SecureString"
#   value       = rsadecrypt(aws_instance.sqlserver.password_data, join("", [var.sql-privpem]))
#   overwrite   = true
#   tags        = merge(var.tags, tomap({ "Name" = join("/", ["", var.resource_prefix, var.env, "sql", var.sql_node, "Administrator"]) }))
# }
