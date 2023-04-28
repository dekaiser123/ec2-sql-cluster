# Terraform

This terraform code is used to create infrastructure for MS SQL servers.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.25 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.25 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_sql-cluster"></a> [sql-cluster](#module\_sql-cluster) | ./sql-ec2 | n/a |
| <a name="module_sql-comm"></a> [sql-comm](#module\_sql-comm) | ./sql-comm | n/a |
| <a name="module_sql-fsx"></a> [sql-fsx](#module\_sql-fsx) | ./sql-fsx | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_resourcegroups_group.rg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/resourcegroups_group) | resource |
| [aws_security_group.ansible](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.sql](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_availability_zone.az](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zone) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ec2_managed_prefix_list.all_list](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_managed_prefix_list) | data source |
| [aws_ec2_managed_prefix_list.fsx_ept](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_managed_prefix_list) | data source |
| [aws_ec2_managed_prefix_list.rdp_net](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_managed_prefix_list) | data source |
| [aws_iam_account_alias.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_account_alias) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_security_group.fsx_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group) | data source |
| [aws_subnet.subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnets.subnet_ids](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.vpc_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_env"></a> [env](#input\_env) | Environment | `string` | n/a | yes |
| <a name="input_gitrepo"></a> [gitrepo](#input\_gitrepo) | Name of the git repo | `string` | n/a | yes |
| <a name="input_inbound_rdp_prefix_list"></a> [inbound\_rdp\_prefix\_list](#input\_inbound\_rdp\_prefix\_list) | inbound rdp network prefix list name | `string` | n/a | yes |
| <a name="input_inbound_sql_ip_list"></a> [inbound\_sql\_ip\_list](#input\_inbound\_sql\_ip\_list) | inbound sql ip list | `list(string)` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | prefix for server name | `string` | n/a | yes |
| <a name="input_outbound_all_prefix_list"></a> [outbound\_all\_prefix\_list](#input\_outbound\_all\_prefix\_list) | outbound all prefix list | `list(string)` | n/a | yes |
| <a name="input_outbound_fsx_prefix_list"></a> [outbound\_fsx\_prefix\_list](#input\_outbound\_fsx\_prefix\_list) | outbound fsx prefix list (if using external fsx in different AWS account or On-Prem FileShare) | `string` | `null` | no |
| <a name="input_outbound_fsx_sg"></a> [outbound\_fsx\_sg](#input\_outbound\_fsx\_sg) | outbound fsx sg name (if using external fsx in same AWS account) | `string` | `null` | no |
| <a name="input_pg_name"></a> [pg\_name](#input\_pg\_name) | placement group name | `string` | `null` | no |
| <a name="input_resource_prefix"></a> [resource\_prefix](#input\_resource\_prefix) | prefix name to use on the resource to be deployed | `string` | n/a | yes |
| <a name="input_s3_access_logging_bucket"></a> [s3\_access\_logging\_bucket](#input\_s3\_access\_logging\_bucket) | log access s3 bucket for sql backup s3 bucket | `string` | n/a | yes |
| <a name="input_s3bucket_resources"></a> [s3bucket\_resources](#input\_s3bucket\_resources) | list of required s3 bucket resources | `list(string)` | n/a | yes |
| <a name="input_sns_subscription_email"></a> [sns\_subscription\_email](#input\_sns\_subscription\_email) | Alerts email | `list(string)` | n/a | yes |
| <a name="input_sql_nodes"></a> [sql\_nodes](#input\_sql\_nodes) | Map of SQL node objects | <pre>map(object({<br>    subnet_id = string,<br>    tags      = map(string)<br>  }))</pre> | n/a | yes |
| <a name="input_sql_tags"></a> [sql\_tags](#input\_sql\_tags) | Extra Tags specific to SQL cluster | `map(string)` | n/a | yes |
| <a name="input_sqlserver_ami"></a> [sqlserver\_ami](#input\_sqlserver\_ami) | Latest AMI with SSM agent preinstalled | `string` | n/a | yes |
| <a name="input_sqlserver_disk_config"></a> [sqlserver\_disk\_config](#input\_sqlserver\_disk\_config) | array of disk objects { description, lun, driveletter, size\_gb } that will be created for each database server. Drive letter is unused in TF but is passed through to downstream. | `list(map(string))` | n/a | yes |
| <a name="input_sqlserver_instance_type"></a> [sqlserver\_instance\_type](#input\_sqlserver\_instance\_type) | Instance Type | `string` | n/a | yes |
| <a name="input_sqlserver_volume_iops"></a> [sqlserver\_volume\_iops](#input\_sqlserver\_volume\_iops) | Volume iops | `number` | n/a | yes |
| <a name="input_sqlserver_volume_size"></a> [sqlserver\_volume\_size](#input\_sqlserver\_volume\_size) | Volume capacity size in GB | `number` | n/a | yes |
| <a name="input_sqlserver_volume_throughput"></a> [sqlserver\_volume\_throughput](#input\_sqlserver\_volume\_throughput) | Volume throughput in MiB/s | `number` | n/a | yes |
| <a name="input_sqlserver_volume_type"></a> [sqlserver\_volume\_type](#input\_sqlserver\_volume\_type) | Volume type | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of the tags to use on the resources that are deployed. | `map(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | vpc id where subnets reside | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_Sqlserver_details"></a> [Sqlserver\_details](#output\_Sqlserver\_details) | Sqlserver details for downstream |
| <a name="output_account_details"></a> [account\_details](#output\_account\_details) | AWS account details |
| <a name="output_ansible_sg_details"></a> [ansible\_sg\_details](#output\_ansible\_sg\_details) | ansible sg id |
| <a name="output_sql_comm_details"></a> [sql\_comm\_details](#output\_sql\_comm\_details) | SQL common details |
| <a name="output_sql_fsx_details"></a> [sql\_fsx\_details](#output\_sql\_fsx\_details) | SQL fsx file-share dns |

## Dependencies

Below are aws resources provisioned from other terraform bootstraps or cfn

| Name  | Default | Description |
|-------|---------|-------------|
| `*_prefix_list` | n/a | all the input prefix lists |
| `pg_name` | n/a | input placement group name (optional) |
| `*s3bucket*` | n/a | all the input s3 logging and resource buckets |
| `outbound_fsx_sg` | n/a | all the input fsx security group name (optional) |
| `/Shared/AD*` | n/a | all the AD items in SSM parameter |
| `FsxWitness` | n/a | an existing FSx in same or different AWS account (Can use On-Prem FileShare Server in which you must specify the outbound_fsx_prefix_list) |

## Example for Manual Provision

Below is an example of running the windows version of the terraform application. This infrastructre is deployed using a multi-step plan and apply. The working root path needs to be in the terraform directory of this repo.

```cmd
# Terraform init
terraform init -backend-config=".\envs\{EnvType}\terraform_state.tfvars"

# Terraform plan - All resources
terraform plan -var-file=".\envs\{EnvType}\terraform.tfvars"

# Terraform apply - All resources
terraform apply -auto-approve -var-file=".\envs\{EnvType}\terraform.tfvars"

```

## Example for defining sql_nodes object in terraform.tfvars

Below is an example of different node configurations that are available from this infrastructure. Ensure the primary node is always the first object.

```hcl
# 4 nodes (3 sync + 1 async) over 4 AZ subnets
sql_nodes = {
    "01": {
      subnet_id = "subnet-a"
      tags      = {
        Role = "primary"
        AGMode = "sync"
      }
    }
    "02": {
      subnet_id = "subnet-b"
      tags      = {
        Role = "secondary"
        AGMode = "sync"
      }
    }
    "03": {
      subnet_id = "subnet-c"
      tags      = {
        Role = "secondary"
        AGMode = "sync"
      }
    }
    "04": {
      subnet_id = "subnet-d"
      tags      = {
        Role = "backup"
        AGMode = "async"
      }
    }
  }

# 5 nodes (3 sync + 2 async) over 3 AZ subnets
sql_nodes = {
    "01": {
      subnet_id = "subnet-a"
      tags      = {
        Role = "primary"
        AGMode = "sync"
      }
    }
    "02": {
      subnet_id = "subnet-b"
      tags      = {
        Role = "secondary"
        AGMode = "sync"
      }
    }
    "03": {
      subnet_id = "subnet-c"
      tags      = {
        Role = "backup"
        AGMode = "async"
      }
    }
    "04": {
      subnet_id = "subnet-a"
      tags      = {
        Role = "spare"
        AGMode = "sync"
      }
    }
    "05": {
      subnet_id = "subnet-b"
      tags      = {
        Role = "spare"
        AGMode = "async"
      }
    }
  }
```

## Reference

[Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest)

[Always On availability groups](https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/always-on-availability-groups-sql-server)


## 🛈 Notes

- Values for variables are in the `terraform.tfvars` file under each environment folder.
- `variables.tf` contains variable definitions, no values.
- Private key can be stored in secretmanager or secure parameter store if used (currently commented out in `sql_comm` module).
- Order of spare nodes is important of ownership of the cluster.
- Match the number of initial order of nodes to how many AZs is available in your region with the appropiate `Role` tag. Example if your region only has 3 AZs, then the first three nodes in the `sql_nodes` map object needs to have a `Role` tag other than `spare`.
- For SQL 2016-2019 Enterprise maximum supported nodes is 9 for AlwaysOn AG. Limits apply to number of synchronous secondary replicas.
- This can be used to provision a single node SQL server, but `output_sql_fsx_details = "standalone"`
- Replace any fields `< value >` with its correspondent