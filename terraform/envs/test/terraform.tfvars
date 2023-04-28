resource_prefix = "<project>"
env             = "test"
name_prefix     = "<hostname prefix ideally string length of 2>" #can be changed for testing newservers
#######

sqlserver_instance_type     = "<instance type>"
sqlserver_ami               = "<ami with SSM agent preinstalled>"
sqlserver_volume_size       = 100
sqlserver_volume_type       = "gp3"
sqlserver_volume_iops       = 3000
sqlserver_volume_throughput = 125

sqlserver_disk_config = [
  {
    description = "data01"
    device_name = "xvdf"
    driveletter = "D"
    size_gb     = 100
    type        = "gp3"
    iops        = 3000
    throughput  = 125
  },
  # {
  #   description = "data02"
  #   device_name = "xvdg"
  #   driveletter = "D"
  #   size_gb     = 100
  #   type        = "gp3"
  #   iops        = 3000
  #   throughput  = 125
  # },
  {
    description = "tlogs01"
    device_name = "xvdl"
    driveletter = "L"
    size_gb     = 50
    type        = "gp3"
    iops        = 3000
    throughput  = 125
  },
  # {
  #   description = "logs02"
  #   device_name = "xvdm"
  #   driveletter = "L"
  #   size_gb     = 16
  #   type        = "gp3"
  #   iops        = 3000
  #   throughput  = 125
  # },
  {
    description = "tempdb01"
    device_name = "xvdt"
    driveletter = "T"
    size_gb     = 20
    type        = "gp3"
    iops        = 3000
    throughput  = 125
  },
  {
    description = "tempdb02"
    device_name = "xvdu"
    driveletter = "T"
    size_gb     = 20
    type        = "gp3"
    iops        = 3000
    throughput  = 125
  },
  {
    description = "tempdb03"
    device_name = "xvdv"
    driveletter = "T"
    size_gb     = 20
    type        = "gp3"
    iops        = 3000
    throughput  = 125
  },
  # {
  #   description = "tempdb04"
  #   device_name = "xvdw"
  #   driveletter = "T"
  #   size_gb     = 8
  #   type        = "gp3"
  #   iops        = 3000
  #   throughput  = 125
  # },
  {
    description = "backup"
    device_name = "xvdz"
    driveletter = "Z"
    size_gb     = 40
    type        = "gp3"
    iops        = 3000
    throughput  = 125
  }
]

#sql_fsx_storage_capacity    = 32
#sql_fsx_throughput_capacity = 16

###################################### tags ######################
tags = {
  Createdby                = "terraform"
  Component                = "sql"
}

## AD object for cluster and listener. Need to be unique
sql_tags = {
  ClusterName  = "Cluster01"
  AGListenerName  = "AGL01" #to add multiple listeners seperate with comma, but requires multiple AGs
  AGName = "AG"
  FsxWitness = "<fileshare dns>"
}

sql_nodes = {
    "01": {
      subnet_id = "<subnet id A>"
      tags      = {
         Role = "primary"
         AGMode = "sync"
      }
    }
    "02": {
      subnet_id = "<subnet id B>"
      tags      = {
          Role = "secondary"
          AGMode = "sync"
      }
    }
    "03": {
      subnet    = "<subnet id C>"
      tags      = {
          Role = "DR"
          AGMode = "async"
      }
    }
  }

sns_subscription_email = [
  "<email address>"
]

s3_access_logging_bucket = "<accesslogbucket>"
s3bucket_resources = [
  "arn:aws:s3:::<Artifact bucket>", #Artifact bucket
  "arn:aws:s3:::<Artifact bucket>/*"
]

vpc_id = "<vpc id>"
outbound_all_prefix_list = [
  "<prefix list>"
]
inbound_rdp_prefix_list = "<prefix list>"
inbound_sql_ip_list = [
  "<IPs/CIDR blocks>"
]
gitrepo = "ec2-sql-cluster"
#outbound_fsx_sg = "test"
outbound_fsx_prefix_list = "<prefix list>"
#pg_name = "<placement group name>"