variable "resource_prefix" {
  description = "prefix name to use on the resource to be deployed"
  type = string
}
variable "env" {
  description = "Environment"
  type = string
}
variable "name_prefix" {
  description = "prefix for server name"
  type = string
}

variable "sqlserver_ami" {
  description = "Latest AMI with SSM agent preinstalled"
  type = string
}
variable "sqlserver_instance_type" {
  description = "Instance Type"
  type = string
}
variable "sqlserver_volume_size" {
  description = "Volume capacity size in GB"
  type = number
}
variable "sqlserver_volume_type" {
  description = "Volume type"
  type = string
}
variable "sqlserver_volume_iops" {
  description = "Volume iops"
  type = number
}
variable "sqlserver_volume_throughput" {
  description = "Volume throughput in MiB/s"
  type = number
}

variable "sqlserver_disk_config" {
  description = "array of disk objects { description, lun, driveletter, size_gb } that will be created for each database server. Drive letter is unused in TF but is passed through to downstream."
  type        = list(map(string))
}

# variable "sql_fsx_storage_capacity" {}
# variable "sql_fsx_throughput_capacity" {}

#################################### variables for tags ###################################
variable "sns_subscription_email" {
  description = "Alerts email"
  type = list(string)
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed."
}

variable "sql_tags" {
  description = "Extra Tags specific to SQL cluster"
  type        = map(string)
}

variable "sql_nodes" {
  description = "Map of SQL node objects"
  type        = map(object({
    subnet_id = string,
    tags      = map(string)
  }))
}

variable "s3_access_logging_bucket" {
  description = "log access s3 bucket for sql backup s3 bucket"
  type = string
}

variable "outbound_all_prefix_list" {
  description = "outbound all prefix list"
  type = list(string)
}

variable "vpc_id" {
  description = "vpc id where subnets reside"
  type = string
}

variable "inbound_rdp_prefix_list" {
  description = "inbound rdp network prefix list name"
  type = string
}

variable "inbound_sql_ip_list" {
  description = "inbound sql ip list"
  type = list(string)
}

variable "s3bucket_resources" {
  description = "list of required s3 bucket resources"
  type = list(string)
}

variable "gitrepo" {
  description = "Name of the git repo"
  type = string
}

variable "outbound_fsx_sg" {
  description = "outbound fsx sg name (if using external fsx in same AWS account)"
  type = string
  default = null
}

variable "outbound_fsx_prefix_list" {
  description = "outbound fsx prefix list (if using external fsx in different AWS account or On-Prem FileShare)"
  type = string
  default = null
}

variable "pg_name" {
  description = "placement group name"
  type = string
  default = null
}