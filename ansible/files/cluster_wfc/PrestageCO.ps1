#set the log file location 
$LogLocation="C:\SQL\logs"
$LogFile="PrestageCO.log"
$StatusFile="PrestageCO_Status.log"

#set create Log Folder if not exist 
if (-NOT (Test-Path -path $LogLocation) ) {new-item -Path $LogLocation -ItemType "Directory"} 

#Delete old log files
if (Test-Path -path $LogLocation"\"$LogFile) {remove-item -Path $LogLocation"\"$LogFile -Force}
if (Test-Path -path $LogLocation"\"$StatusFile) {remove-item -Path $LogLocation"\"$StatusFile -Force}

#CO functions only accept single argument, multiple arguments cause the functions to fail
function CheckCO($CO) {
  $R=$null
  try {
      $R = Get-ADComputer -identity $CO
  }
  catch {
      $R = $_
      out-file $logLocation"\"$StatusFile -InputObject $R -Append -NoClobber -Encoding UTF8
  }
  return $R
}

function AddCO($CO) {
  $check = CheckCO($CO)
  #Write-Host($result)
  $R=$null
  if ($check -match "Cannot find an object") {
    out-file $logLocation"\"$LogFile -InputObject  "$CO ADComputer Object does not exist" -Append -NoClobber -Encoding UTF8
    try {
      if ([string]::IsNullOrEmpty($Description)) {
        $R = New-ADcomputer -Name $CO -Enabled $false -path $JoinADOU
      } else {
        $R = New-ADcomputer -Name $CO -Description $Description -Enabled $false -path $JoinADOU
      }
    }
    catch {
        $R = $_
        out-file $logLocation"\"$StatusFile -InputObject $R -Append -NoClobber -Encoding UTF8                
    }
    
    $check = "start"
    While ($check -match "Cannot find an object") {
      start-sleep 10
      out-file $logLocation"\"$LogFile -InputObject  "$CO ADComputer Object still does not exist yet" -Append -NoClobber -Encoding UTF8
      $check = CheckCO($CO)
    }

  } else {
    out-file $logLocation"\"$LogFile -InputObject  "$CO exists" -Append -NoClobber -Encoding UTF8
  }

  return $R
}

Import-Module ServerManager -Force
Install-WindowsFeature -Name RSAT-AD-PowerShell
Install-WindowsFeature -Name RSAT-ADLDS
Import-Module ActiveDirectory -Force
#import-module FailOverClusters -Force

$DomainName = (Get-SSMParameterValue -Name "/Shared/AD/MicrosoftAD/RootDomain").Parameters.value
$JoinADOU=(Get-SSMParameterValue -Name "/Shared/AD/DomainJoin/OUpath").Parameters.value
$SrvAcc=(Get-SSMParameterValue -Name "/Shared/AD/SRV/SQL_USER").Parameters.value
$SrvAcc=($DomainName -split "\.")[0] + "\" + $SrvAcc.Substring(0,[math]::min(20,$SrvAcc.length))
$Instanceid=Get-EC2InstanceMetadata -Category InstanceId
$ClusterName=(get-EC2Tag -Filter @{Name="resource-id"; Value=$Instanceid}, @{Name="key";Value="ClusterName"}).Value
$AG_Listener_list = (get-EC2Tag -Filter @{Name="resource-id"; Value=$Instanceid}, @{Name="key";Value="AGListenerName"}).Value.split(",")

$Description = $null
$CNOexist = AddCO($ClusterName)

if ([string]::IsNullOrEmpty($CNOexist)) {

  $B = Get-ADComputer -identity $ClusterName
  if ((dsacls $B.DistinguishedName|where-object {$_ -match "Full" -and $_ -match "Allow" -and $_ -match $SrvAcc}).count -eq 0){
    $AddControl="dsacls " + """$B""" +" /G "+$SrvAcc+":GA;"
    cmd /c $AddControl
    }

  for ($j=0;$j -lt $AG_Listener_list.count;$j++) {
    $Description ="AlwaysOn Group Listener " + $AG_Listener_list[$j] +" for " + $ClusterName
    $CVOexist=AddCO($AG_Listener_list[$j])
    if ([string]::IsNullOrEmpty($CVOexist)) {
      $B = Get-ADComputer -identity $AG_Listener_list[$j]
      #cluster CNO does not have full control permission on the CVO, then grant the permission 
      if ((dsacls $B.DistinguishedName|where-object {$_ -match "Full" -and $_ -match "Allow" -and $_ -match $ClusterName}).count -eq 0){
        $AddControl="dsacls " + """$B""" +" /G "+($DomainName -split "\.")[0]+"\"+$ClusterName+"$"""+":GA;"
        cmd /c $AddControl 
        }
    }
  }

}