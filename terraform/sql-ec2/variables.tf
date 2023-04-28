variable "resource_prefix" {
  description = "prefix name to use on the resource to be deployed. (will be suffixed with a random number)"
}
variable "env" {}
variable "name_prefix" {}

variable "vpc_id" {
  description = "VPC ID"
}
variable "subnet_id" {}
variable "az_suffix" {nullable = false}

variable "sql_node" {}
variable "ami_id" {}
variable "instance_type" {}
variable "pg_name" {}

variable "volume_type" {}
variable "volume_size" {}
variable "volume_iops" {}
variable "volume_throughput" {}

variable "sqlserver_disk_config" {
  type = list(map(string))
}

variable "gitrepo" {}
variable "sql_webhookbucket" {}
variable "sql_sg" {}
# variable "sql-keypair" {}
# variable "sql-privpem" {}
variable "sql-instanceprofile" {}

variable "sns_topic" {}
variable "tags" {}