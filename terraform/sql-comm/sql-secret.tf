# resource "aws_secretsmanager_secret" "private_rsa_key" {

#   name                    = join("/", ["", var.resource_prefix,var.env, "sql", "priv-keypair"])
#   description             = "private pem file for SQL hosts"
#   recovery_window_in_days = 0
#   depends_on              = [tls_private_key.rsakey]
#   tags                    = merge(var.tags, tomap({ "Name" = join("-", ["", var.resource_prefix,var.env, "sql", "private-keypair"]) }))
# }

# resource "aws_secretsmanager_secret_version" "private_rsa_value" {

#   secret_id     = aws_secretsmanager_secret.private_rsa_key.id
#   secret_string = join("", tls_private_key.rsakey.*.private_key_pem)
# }
