output "witness_dns" {
  description = "Fsx fileshare cluster witness"
  value       = aws_fsx_windows_file_system.SqlCluster_FileShare.dns_name
}
