#!/usr/bin/pwsh
param (
    [Parameter(Mandatory=$true)][string]$S3AppBucket,
    [Parameter(Mandatory=$true)][string]$AnsiblePlaybook
)

$AnsibleHostsFileName = "sql_host"
$TerraformOutput = Get-Content $env:TERRAFORM_OUTPUT_FILE | ConvertFrom-Json
$hosts = 0

#$SqlServerDetails = $TerraformOutput.sql_node_01_details.value
$SqlServerDetails = $TerraformOutput.Sqlserver_details.value
ForEach ($SqlServer in $SqlServerDetails) {

### Get local user password
#$AdminPassword = (Get-SSMParameterValue -Name $SqlServer.admin_password_secret_name -WithDecryption $true).Parameters.value

### Get domain user password instead of local user password
$DomainName = (Get-SSMParameterValue -Name "/Shared/AD/MicrosoftAD/RootDomain").Parameters.value
$AdminUser = (Get-SSMParameterValue -Name "/Shared/AD/SRV/SQL_USER").Parameters.value
$AdminUser = ($DomainName -split "\.")[0] + "\" + $AdminUser.Substring(0,[math]::min(20,$AdminUser.length))
$AdminPassword = (Get-SSMParameterValue -Name "/Shared/AD/SRV/SQL_PW" -WithDecryption $true).Parameters.value

Add-Member -MemberType NoteProperty -InputObject $SqlServer -Name admin_user -Value $AdminUser
Add-Member -MemberType NoteProperty -InputObject $SqlServer -Name admin_password -Value $AdminPassword
}
Remove-Item  $AnsibleHostsFileName -ErrorAction SilentlyContinue

"[SQL_SVRNODE]" >> $AnsibleHostsFileName
$AnsiblePasswordVariables = @()
ForEach ($SqlServer in $SqlServerDetails) {

$UserVariableName = "$($SqlServer.server_name -replace '[-]')_USER"
$PasswordVariableName = "$($SqlServer.server_name -replace '[-]')_PW"

### Use Domain user instead of local user
"$($SqlServer.server_name) ansible_host=$($SqlServer.ip_address) ansible_user=`"{{ $UserVariableName }}`" ansible_password=`"{{ $PasswordVariableName }}`"" >> $AnsibleHostsFileName
$AnsiblePasswordVariables += "$UserVariableName=`"$($SqlServer.admin_user)`""
$AnsiblePasswordVariables += "$PasswordVariableName=`"$($SqlServer.admin_password)`""

$hosts = $hosts + 1
}

### Use local Administrator
#"$($SqlServer.server_name) ansible_host=$($SqlServer.ip_address) ansible_user=Administrator ansible_password=`"{{ $PasswordVariableName }}`"" >> $AnsibleHostsFileName
#$AnsiblePasswordVariables += "$PasswordVariableName=`"$($SqlServer.admin_password)`""
#}

$AnsiblePasswordVariables = $AnsiblePasswordVariables -join " "
'[SQL_SVRNODE:vars]' >> $AnsibleHostsFileName
"ansible_port=5986" >> $AnsibleHostsFileName
"ansible_become=false" >> $AnsibleHostsFileName
"ansible_connection=winrm" >> $AnsibleHostsFileName
"ansible_winrm_server_cert_validation=ignore" >> $AnsibleHostsFileName
"ansible_winrm_transport=ntlm" >> $AnsibleHostsFileName
"ansible_shell_type=powershell" >> $AnsibleHostsFileName
"ansible_shell_executable=None" >> $AnsibleHostsFileName

### Aditional variables

$SmcAccount = $TerraformOutput.account_details.account_alias.value
$localAccount += "localAccount=$($SmcAccount)"

$FsxWitnessDetails = $TerraformOutput.sql_fsx_details.value
$cluWitness += "cluWitness=$($FsxWitnessDetails)"

# $Proxy_Password = (Get-SSMParameterValue -Name "/proxy/user/password" -WithDecryption $true).Parameters.value
# $proxyPassword += "proxyPassword=$($Proxy_Password)"
$s3Bucket += "s3Bucket=$($S3AppBucket)"

get-content sql_host

## ansible test connection execution
(ansible all -i sql_host -m win_ping -e ${AnsiblePasswordVariables} -e ${localAccount} -e ${cluWitness}) | Tee-Object -variable pingresult #-e ${proxyPassword}

If (($pingresult | select-string -pattern "SUCCESS").length -eq $hosts) {

    Write-Host "All nodes reachable"
## ansible playbook execution -- NEW-BUILD
    ansible-playbook -i sql_host "$($AnsiblePlaybook).yml" -e ${AnsiblePasswordVariables} -e ${localAccount} -e ${cluWitness} -e ${s3Bucket}

## ansible playbook execution -- RE-BUILD
# ansible-playbook -i sql_host rebuild.yml -e ${AnsiblePasswordVariables} -e ${localAccount} -e ${cluWitness} -e ${proxyPassword}

## ansible playbook destroy terraform
#ansible-playbook -i sql_host destroy.yml -e ${AnsiblePasswordVariables} -e ${localAccount} -e ${cluWitness} -e ${proxyPassword}

} else {
    Write-Host "Not all nodes reachable"
}