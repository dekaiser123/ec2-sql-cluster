#################################### datasource ###################################

data "aws_ssm_parameter" "DirectoryId" {
  name = "/Shared/AD/MicrosoftAD/DirectoryId"
}
