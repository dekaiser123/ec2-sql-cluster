# output "sql_sg" {
#   value       = aws_security_group.sg_sqlserver.id
#   description = "SQL security group ID"
# }

output "sql_instance_profile" {
  description = "iam_instance_profile name"
  value       = aws_iam_instance_profile.sql-instanceprofile.name
}

# output "sql_keypair_id" {
#   description = "Key-Pair ID"
#   value       = aws_key_pair.sql-keypair.id
# }

output "sqlbackup_s3" {
  description = "S3 bucket for SQL backup"
  value       = aws_s3_bucket.sql-backup.id
}

# output "sql_priv_pem" {
#   description = "priv pem key"
#   value       = join("", tls_private_key.rsakey.*.private_key_pem)
# }

output "sns_topic_name" {
  value       = aws_sns_topic.ec2-alerts.name
  description = "SNS Topic Name"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.ec2-alerts.arn
  description = "SNS Topic ARN"
}