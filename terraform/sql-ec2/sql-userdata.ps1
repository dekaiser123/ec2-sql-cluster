<powershell>
function InfoLog($message) {
    $LogDate = Get-Date
    $OutContent = "[$LogDate]`tInfo`t`t$message`n"
    Add-Content $TaskLogPath\$LogFile $OutContent
    C:\SQL\Write-CWLogsEntry.ps1 -LogGroupName "EC2" -LogStreamName ("SQL_"+$global:instanceId) -LogString $message
}

function ErrorLog($message) {
    $LogDate = Get-Date
    $OutContent = "[$LogDate]`tError`t`t$message`n"
    Add-Content $TaskLogPath\$LogFile $OutContent
    C:\SQL\Write-CWLogsEntry.ps1 -LogGroupName "EC2" -LogStreamName ("SQL_"+$global:instanceId) -LogString ("ERR: "+$message)
}

$TaskLogPath = "C:\SQL\logs"
$Logfile = "userdata.log"
if ((Test-Path $TaskLogPath) -eq $false) {
    $null = New-Item -path $TaskLogPath -type directory
}
if ((Test-Path $TaskLogPath\$LogFile) -eq $false) {
    $null = New-Item $TaskLogPath\$LogFile -ItemType file
}
Add-Content $TaskLogPath\$LogFile "Date`t`t`tCategory`tDetails"

$Error.clear()
aws s3 cp "s3://${s3webhookbucket}/${environment}-${repository}.zip" "C:\SQL" --no-progress
Add-Type -Assembly System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead("C:\SQL\${environment}-${repository}.zip")
$entries = $zip.Entries | where {$_.FullName -like "terraform/scripts*"}
$entries | foreach {[IO.Compression.ZipFileExtensions]::ExtractToFile($_, ("C:\SQL\") + $_.Name, $true)}
$zip.Dispose()
$global:instanceId = Get-EC2InstanceMetadata -Category InstanceId
if ($Error) {
    New-Item $TaskLogPath\"fatal_no_scripts.log" -ItemType file
    throw("Could not extract scripts from repo")
    exit 1
}

Write-Host("Add Registry entry for server_role")
try {
    $DomainName = (Get-SSMParameterValue -Name "/Shared/AD/MicrosoftAD/RootDomain").Parameters.value
    $SQLAdmins = (Get-SSMParameterValue -Name "/Shared/AD/SQLAdmins").Parameters.value
    $SQLAdmins = ($DomainName -split "\.")[0] + "\" + $SQLAdmins
    InfoLog("EC2 instance belongs to AWS Account:$("${accountalias}:${accountid}")")
    if ((Test-Path HKLM:\SYSTEM\SQL) -eq $false) {
        $null = New-Item -path HKLM:\SYSTEM -Name SQL -type directory
    }
    New-ItemProperty -Path HKLM:\SYSTEM\SQL -Name server_role -PropertyType String -Value "${role}" -Force
    New-ItemProperty -Path HKLM:\SYSTEM\SQL -Name sqladmins -PropertyType String -Value $SQLAdmins -Force
    New-ItemProperty -Path HKLM:\SYSTEM\SQL -Name account_alias -PropertyType String -Value "${accountalias}" -Force
    New-ItemProperty -Path HKLM:\SYSTEM\SQL -Name account_id -PropertyType String -Value "${accountid}" -Force
    New-ItemProperty -Path HKLM:\SYSTEM\SQL -Name env -PropertyType String -Value "${environment}" -Force
    InfoLog("Reg Property set for server_role")
}
catch {
    ErrorLog($_)
    exit 1
}

Write-Host("Execute Scripts and check Timezone")
try {
    C:\SQL\ConfigureRemotingForAnsible.ps1 -ForceNewSSLCert -EnableCredSSP
    # C:\SQL\set_infraproxy.ps1 replaced with your own proxy script, ensuring you set no_proxy=169.254.169.254
    C:\SQL\set_region.ps1
    C:\SQL\DisableIEEnhanceSG.ps1
    C:\SQL\DisableUAC.ps1
    C:\SQL\disable_ipv6.ps1
    InfoLog("Executed Config Scripts")
    $timezone = Get-TimeZone -ListAvailable | where-object { $_.DisplayName -like "*Canberra, Melbourne, Sydney*" } | Select-Object -ExpandProperty "ID"
    if (-not (([System.TimeZoneInfo]::Local | Select-Object -expandproperty Id) -match $timezone)) {
        Set-TimeZone -Id $timezone -PassThru
        write-host("Info: Setup Timezone completed: $timezone")
        InfoLog("Set AEST Timezone")
    }
    Set-Item -Path WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 2048  # this is the max mem in MB
    Restart-Service -Name WinRM
    InfoLog("WinRM setup")
}
catch {
    ErrorLog($_)
    exit 1
}

Write-Host("Configure Cloudwatch Agent")
try {
    $content = Get-Content "C:\SQL\cw_agent_config.json"
    $content = $content -replace "{hostname}", "${computer_name}"
    $content | Out-File -FilePath "C:\ProgramData\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent.json" "default" -Force
    InfoLog("Cloudwatch Agent configured")
}
catch {
    ErrorLog($_)
    exit 1
}

Write-Host("Joining Computer to Domain")
try {
    $DomainJoinUsername = (Get-SSMParameterValue -Name "/Shared/AD/DomainJoin/ServiceAccount").Parameters.value
    $DomainJoinPassword = (Get-SSMParameterValue -Name "/Shared/AD/DomainJoin/Password" -WithDecryption $true).Parameters.value | ConvertTo-SecureString -AsPlainText -Force
    $DomainJoinOUpath = (Get-SSMParameterValue -Name "/Shared/AD/DomainJoin/OUpath").Parameters.value
    $JoinADAccountwithDomain = ($DomainName -split "\.")[0] + "\" + $DomainJoinUsername
    $credential = New-Object System.Management.Automation.PSCredential($JoinADAccountwithDomain, $DomainJoinPassword) -ErrorAction Stop
    Set-LocalUser -Name "Administrator" -PasswordNeverExpires 1
    Rename-Computer -ComputerName $env:COMPUTERNAME -NewName "${computer_name}" -Force
    Add-Computer -DomainName $DomainName -Credential $credential -OUPath "$DomainJoinOUpath" -Force -Options JoinWithNewName, AccountCreate -PassThru -Verbose -ErrorAction Stop
    gpupdate /force
    InfoLog("Joined Computer to Domain and GPO update")
}
catch {
    ErrorLog ($_)
    exit 1
}

Write-Host("ScheduledTask to Add sqladmins to the local administrators group")
try {
     $SrvAcc = (Get-SSMParameterValue -Name "/Shared/AD/SRV/SQL_USER").Parameters.value
     $SrvAcc = ($DomainName -split "\.")[0] + "\" + $SrvAcc.Substring(0,[math]::min(20,$SrvAcc.length))
     $STPrincipal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
     $cmd1 = "add-localgroupmember -group administrators -member " + $SQLAdmins + ", " + $SrvAcc
     $value = "C:\SQL\Write-CWLogsEntry.ps1 -LogGroupName EC2 -LogStreamName SQL_" + $global:instanceId
     $cmd2 = "-ExecutionPolicy ByPass -File C:\SQL\Grant-UserRight.ps1 -AdUsername " + $SrvAcc + " -CW `"$value`""
     $action = (New-ScheduledTaskAction -Execute 'c:\windows\system32\WindowsPowerShell\v1.0\powershell.exe' -Argument $cmd1), (New-ScheduledTaskAction -Execute 'c:\windows\system32\WindowsPowerShell\v1.0\powershell.exe' -Argument $cmd2)
     $trigger = New-ScheduledTaskTrigger -AtStartup
     $trigger.EndBoundary = (Get-Date).AddMinutes(5).ToString('s')
     Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "AddLocalAdmin" -Description "Add LocalAdmin to Domain" -Principal $STPrincipal
     InfoLog("ScheduledTask added for sqladmins to local admin group")
}
catch {
    ErrorLog($_)
    exit 1
}

try {
    start-sleep -s 30
    InfoLog("Restarting Server")
    Restart-Computer -Force
}
catch {
    ErrorLog($_)
    exit 1
}
</powershell>