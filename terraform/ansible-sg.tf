locals {
  sg_name_ansible = lower(join("-", [var.resource_prefix, var.env, "ansible", "sg"]))
  ingress_rules_ansible = [
    {
      description     = "SSH Access within VPC SMC",
      from_port       = "22",
      to_port         = "22",
      protocol        = "tcp",
      cidr_blocks     = local.vpc_cidr_block
    }
  ]
  egress_rules_ansible = [
    {
      description     = "WinRM-HTTPS Access within VPC SMC",
      from_port       = "5986",
      to_port         = "5986",
      protocol        = "tcp",
      cidr_blocks     = local.vpc_cidr_block
    },
    {
      description     = "HTTPS access to anywhere",
      from_port       = "443",
      to_port         = "443",
      protocol        = "tcp",
      cidr_blocks     = ["0.0.0.0/0"]
    }
  ]
}

resource "aws_security_group" "ansible" {
  name                   = local.sg_name_ansible
  description            = "Security Group for Ansible Codebuild SQL"
  revoke_rules_on_delete = false
  vpc_id                 = data.aws_vpc.vpc_id.id

  dynamic "ingress" {
    for_each = local.ingress_rules_ansible
    content {
      description      = ingress.value.description
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      security_groups  = lookup(ingress.value, "security_groups", null)
      cidr_blocks      = lookup(ingress.value, "cidr_blocks", null)
      ipv6_cidr_blocks = lookup(ingress.value, "ipv6_cidr_blocks", null)
      prefix_list_ids  = lookup(ingress.value, "prefix_list_ids", null)
      self             = lookup(ingress.value, "self", null)
    }
  }

  dynamic "egress" {
    for_each = local.egress_rules_ansible
    content {
      description      = egress.value.description
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      security_groups  = lookup(egress.value, "security_groups", null)
      cidr_blocks      = lookup(egress.value, "cidr_blocks", null)
      ipv6_cidr_blocks = lookup(egress.value, "ipv6_cidr_blocks", null)
      prefix_list_ids  = lookup(egress.value, "prefix_list_ids", null)
      self             = lookup(egress.value, "self", null)
    }
  }

  tags = merge(
    tomap({ "Name" = local.sg_name_ansible, }),
    local.tags,
    var.tags,
  )

}