# locals {
#   key_name = join("-", [var.resource_prefix, var.env, "sql", "key-pair"])
# }

# resource "tls_private_key" "rsakey" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# resource "aws_key_pair" "sql-keypair" {
#   key_name   = local.key_name
#   public_key = tls_private_key.rsakey.public_key_openssh
#   tags       = merge(var.tags, tomap({ "Name" = local.key_name }))
# }
