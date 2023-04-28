locals {
  ec2_metric_alarms = [
    {
      alarm_name          = "ec2-cpu-warning"
      alarm_description   = "CPU Warning Alarm for EC2 Instances"
      create_metric_alarm = true
      comparison_operator = "GreaterThanOrEqualToThreshold"
      metric_name         = "CPUUtilization"
      treat_missing_data  = "missing"
      evaluation_periods  = "2" # Number of failures
      threshold           = "80"
      period              = "300" # seconds
      statistic           = "Average"
      alarm_actions       = [var.sns_topic]
    },
    {
      alarm_name          = "ec2-cpu-critical"
      alarm_description   = "CPU Critical Alarm for EC2 Instances"
      create_metric_alarm = true
      comparison_operator = "GreaterThanOrEqualToThreshold"
      metric_name         = "CPUUtilization"
      treat_missing_data  = "missing"
      evaluation_periods  = "2" # Number of failures
      threshold           = "95"
      period              = "300" # 5 minutes
      statistic           = "Average"
      alarm_actions       = [var.sns_topic]
    },
    {
      alarm_name          = "ec2-status-check"
      alarm_description   = "Status Check for EC2 Instances"
      create_metric_alarm = true
      comparison_operator = "GreaterThanOrEqualToThreshold"
      metric_name         = "StatusCheckFailed"
      treat_missing_data  = "breaching"
      evaluation_periods  = "1" # Number of failures
      threshold           = "1"
      period              = "60" # 1 minute
      statistic           = "Average"
      alarm_actions       = [var.sns_topic]
    },
    {
      alarm_name          = "ec2-recovery"
      alarm_description   = "Trigger a recovery when instance status check fails for 5 consecutive minutes"
      create_metric_alarm = true
      comparison_operator = "GreaterThanThreshold"
      metric_name         = "StatusCheckFailed_System"
      treat_missing_data  = "breaching"
      evaluation_periods  = "5" # Number of failures
      threshold           = "0"
      period              = "60" # 1 minute
      statistic           = "Minimum"
      alarm_actions       = [var.sns_topic]
    },
    {
      alarm_name          = "ec2-low-cpu-credits"
      alarm_description   = "Trigger when CPU Credit is low"
      create_metric_alarm = length(regexall("t\\d", lower(var.instance_type))) == 1 ? true : false
      comparison_operator = "LessThanThreshold"
      metric_name         = "CPUCreditBalance"
      treat_missing_data  = "breaching"
      evaluation_periods  = "5" # Number of failures
      threshold           = "50"
      period              = "300" # 5 minutes
      statistic           = "Average"
      alarm_actions       = [var.sns_topic]
    }
  ]

  ec2_cwagent_metric_LogicalDisk_alarms = [
    {
      alarm_name          = "ec2-free-space-warning"
      alarm_description   = "Free Space Warning Alarm for EC2 Instances"
      create_metric_alarm = true
      comparison_operator = "LessThanOrEqualToThreshold"
      metric_name         = "LogicalDisk % Free Space"
      treat_missing_data  = "missing"
      evaluation_periods  = "2" # Number of failures
      threshold           = "20"
      period              = "300" # seconds
      statistic           = "Average"
      alarm_actions       = [var.sns_topic]
    },
    {
      alarm_name          = "ec2-free-space-critical"
      alarm_description   = "Free Space Critical Alarm for EC2 Instances"
      create_metric_alarm = true
      comparison_operator = "LessThanOrEqualToThreshold"
      metric_name         = "LogicalDisk % Free Space"
      treat_missing_data  = "missing"
      evaluation_periods  = "1" # Number of failures
      threshold           = "10"
      period              = "300" # seconds
      statistic           = "Average"
      alarm_actions       = [var.sns_topic]
    }
  ]

  ec2_cwagent_metric_Memory_alarms = [
    {
      alarm_name          = "ec2-memory-warning"
      alarm_description   = "Memory Warning Alarm for EC2 Instances"
      create_metric_alarm = true
      comparison_operator = "GreaterThanOrEqualToThreshold"
      metric_name         = "Memory % Committed Bytes In Use"
      treat_missing_data  = "missing"
      evaluation_periods  = "2" # Number of failures
      threshold           = "85"
      period              = "300" # seconds
      statistic           = "Average"
      alarm_actions       = [var.sns_topic]
    },
    {
      alarm_name          = "ec2-memory-critical"
      alarm_description   = "Memory Critical Alarm for EC2 Instances"
      create_metric_alarm = true
      comparison_operator = "GreaterThanOrEqualToThreshold"
      metric_name         = "Memory % Committed Bytes In Use"
      treat_missing_data  = "missing"
      evaluation_periods  = "1" # Number of failures
      threshold           = "95"
      period              = "300" # seconds
      statistic           = "Average"
      alarm_actions       = [var.sns_topic]
    }
  ]

  # instance = { 
  #   "${aws_instance.sqlserver.tags["Name"]}" = "${aws_instance.sqlserver.id}" 
  # }
  
  sql_ec2_alerts_dim = flatten([
    for obj in local.ec2_metric_alarms :
        merge(obj, { "dimensions" = { 
          "InstanceId"  = aws_instance.sqlserver.id 
          },
          "name_suffix" = local.sql_instance_name,
          "namespace"   = "AWS/EC2"
        })
  ])

  sql_ec2_cwagent_Memory_alerts_dim = flatten([
    for obj in local.ec2_cwagent_metric_Memory_alarms :
        merge(obj, { "dimensions" = { 
          "InstanceId"   = aws_instance.sqlserver.id
          "ImageId"      = var.ami_id
          "InstanceType" = var.instance_type
          "objectname"   = "Memory"
          },
          "name_suffix" = local.sql_instance_name,
          "namespace"   = "CWAgent"
        })
  ])

  disks = { for volume in aws_ebs_volume.sql-disk : volume.tags.Name => volume.tags.DriveLetter if length(regexall("TEMPDB", upper(volume.tags.DriveName))) == 0 }

  # sql_ec2_cwagent_LogicalDisk_alerts_dimensions = { for v in range(length(local.disks)) : keys(local.disks)[v] => {
  #   "InstanceId"   = aws_instance.sqlserver.id
  #   "ImageId"      = var.ami_id
  #   "InstanceType" = var.instance_type
  #   "objectname"   = "LogicalDisk"
  #   "instance"     = join("", [values(local.disks)[v], ":"])
  #   }
  # }

  sql_ec2_cwagent_LogicalDisk_alerts_dim = flatten([
    for v in range(length(local.disks)) : [
      for obj in local.ec2_cwagent_metric_LogicalDisk_alarms :
        merge(obj, { "dimensions" = { 
          "InstanceId"   = aws_instance.sqlserver.id 
          "ImageId"      = var.ami_id
          "InstanceType" = var.instance_type
          "objectname"   = "LogicalDisk"
          "instance"     = join("", [values(local.disks)[v], ":"])
          },
          "name_suffix" = keys(local.disks)[v],
          "namespace"   = "CWAgent"
        })
    ]
  ])

  sql_ec2_alerts_total = concat(local.sql_ec2_alerts_dim, local.sql_ec2_cwagent_Memory_alerts_dim, local.sql_ec2_cwagent_LogicalDisk_alerts_dim)

}


### Important: Server recovery alarm
resource "aws_cloudwatch_metric_alarm" "ec2_metric_alarms" {

  for_each = { for o in local.sql_ec2_alerts_total : join("-", [o.alarm_name, o.name_suffix]) => o if o.create_metric_alarm == true}

  alarm_name        = join("-", [var.resource_prefix, var.env, each.key])
  alarm_description = each.value.alarm_description

  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  threshold           = each.value.threshold

  treat_missing_data = each.value.treat_missing_data
  metric_name        = each.value.metric_name
  namespace          = each.value.namespace
  period             = each.value.period
  statistic          = each.value.statistic

  dimensions = each.value.dimensions
  alarm_actions = each.value.alarm_actions
  tags = merge(var.tags, tomap({ "Name" = each.value.alarm_name, }))
}