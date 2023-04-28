variable "resource_prefix" {
  description = "prefix name to use on the resource to be deployed. (will be suffixed with a random number)"
}

variable "env" {}
variable "sql_sg" {}
variable "fsx_subnet_id" {}
variable "fsx_deployment_type" {}
variable "fsx_storage_type" {}
variable "fsx_storage_capacity" {}
variable "fsx_throughput_capacity" {}
variable "fsx_backup_retention" {}
variable "fsx_skip_final_backup" {}



variable "tags" {}
