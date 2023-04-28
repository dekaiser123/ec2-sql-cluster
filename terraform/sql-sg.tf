locals {
  sg_name_sql = lower(join("-", [var.resource_prefix, var.env, "sql", "sg"]))
  ingress_rules_sql = [
    {
      description     = "SQL from IP List",
      from_port       = "1433",
      to_port         = "1433",
      protocol        = "tcp",
      cidr_blocks     = var.inbound_sql_ip_list
    },
    {
      description     = "Health Probe within VPC SMC for NLB",
      from_port       = "58888",
      to_port         = "58888",
      protocol        = "tcp",
      cidr_blocks     = local.vpc_cidr_block
    },
    {
      description     = "RDP from Prefix List",
      from_port       = "3389",
      to_port         = "3389",
      protocol        = "tcp",
      prefix_list_ids = [data.aws_ec2_managed_prefix_list.rdp_net.id]
    },
    {
      description     = "allow inline within SG",
      from_port       = "0",
      to_port         = "0",
      protocol        = "-1",
      self            = true
    },
    {
      description     = "allow inline from Ansible SG",
      from_port       = "5986",
      to_port         = "5986",
      protocol        = "tcp",
      security_groups = [aws_security_group.ansible.id]
    }
  ]
  egress_rules_sql= [
    {
      description     = "allow inline within SG",
      from_port       = "0",
      to_port         = "0",
      protocol        = "-1",
      self            = true
    },
    {
      description     = "FSx access",
      from_port       = "445",
      to_port         = "445",
      protocol        = "tcp",
      security_groups = local.fsx_sg_exist ? [data.aws_security_group.fsx_sg[0].id] : null,
      self            = local.provision_fsx ? null : true,
      prefix_list_ids = local.fsx_prefix_list_exist ? [data.aws_ec2_managed_prefix_list.fsx_ept[0].id] : null
    },
    {
      description     = "All Endpoint access",
      from_port       = "0",
      to_port         = "0",
      protocol        = "-1",
      prefix_list_ids = [ for v in data.aws_ec2_managed_prefix_list.all_list : v.id ]
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

resource "aws_security_group" "sql" {
  name                   = local.sg_name_sql
  description            = "Security Group for SQL"
  revoke_rules_on_delete = false
  vpc_id                 = data.aws_vpc.vpc_id.id

  dynamic "ingress" {
    for_each = local.ingress_rules_sql
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
    for_each = local.egress_rules_sql
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
    tomap({ "Name" = local.sg_name_sql, }),
    local.tags,
    var.tags,
  )

  depends_on = [aws_security_group.ansible]
}