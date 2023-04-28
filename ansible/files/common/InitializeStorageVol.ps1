$TaskLogPath = "C:\SQL\logs"
$Logfile = "InitializeStorageVol.log"
$global:instanceId = ""

function InfoLog($message) {
    $date       = Get-Date
    $OutContent = "[$date]`tInfo`t`t$message`n"
    Add-Content $TaskLogPath\$LogFile $OutContent
}
function ErrorLog($message) {
    $date       = Get-Date
    $OutContent = "[$date]`tError`t`t$message`n"
    Add-Content $TaskLogPath\$LogFile $OutContent
}
function ConfigureLog() {
    if ((Test-Path $TaskLogPath) -eq $false) { 
        $TaskLogCreation = New-Item -path $TaskLogPath -type directory 
    }
    if ((Test-Path $TaskLogPath\$LogFile) -eq $false) { 
        New-Item $TaskLogPath\$LogFile -ItemType file
        Add-Content $TaskLogPath\$LogFile "Date`t`t`tCategory`tDetails" 
    }
}

function MountSingleVolume($Name) {
    $Value = "*"+$Name+"*"
    $Driveletter = ((Get-EC2Volume -Filter @{Name="attachment.instance-id"; Values=$global:instanceId} | Where-Object { $_.Tag.Count -gt 0 -and $_.Tag.Key -eq "DriveName" -and $_.Tag.Value -like $Value }).Tags | Where-Object { $_.Key -eq "DriveLetter"}).Value | select -Unique
    if ($Driveletter.count -gt 1) {
        throw "Not unique DriveLetter, check DriveLetter Tag"
    }
    $Volume = (Get-EC2Volume -Filter @{Name="attachment.instance-id"; Values=$global:instanceId} | Where-Object { $_.Tag.Count -gt 0 -and $_.Tag.Key -eq "DriveName" -and $_.Tag.Value -like $Value }).VolumeId -Replace("vol-","vol")
    $Disk = Foreach($vol in $Volume) { Get-Disk | Where-Object {$_.AdapterSerialNumber -eq $vol -and $_.PartitionStyle -eq "RAW"} }
    If (-not([string]::IsNullOrEmpty($Disk))) {
	    $Disk | Initialize-Disk -Passthru | New-Partition -UseMaximumSize -DriveLetter $Driveletter | Format-Volume -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel ("SQL_"+$Name.ToUpper()) -Confirm:$false
        InfoLog("SQL Storage Volume - " + $Name)
    }
}

ConfigureLog

try {
    $global:instanceId = Get-EC2InstanceMetadata -Category InstanceId
    $TempDriveletter = ((Get-EC2Volume -Filter @{Name="attachment.instance-id"; Values=$global:instanceId} | Where-Object { $_.Tag.Count -gt 0 -and $_.Tag.Key -eq "DriveName" -and $_.Tag.Value -like "*tempdb*" }).Tags | Where-Object { $_.Key -eq "DriveLetter"}).Value | select -Unique
    if ($TempDriveletter.count -gt 1) {
        throw "Not unique DriveLetter, check DriveLetter Tag"
    }
    $TempVolume = (Get-EC2Volume -Filter @{Name="attachment.instance-id"; Values=$global:instanceId} | Where-Object { $_.Tag.Count -gt 0 -and $_.Tag.Key -eq "DriveName" -and $_.Tag.Value -like "*tempdb*" }).VolumeId -Replace("vol-","vol")
    $TempDisks  = Foreach($vol in $TempVolume) { Get-PhysicalDisk | Where-Object {$_.AdapterSerialNumber -eq $vol } }
    $VirtDisk = Foreach($vol in $TempVolume) { Get-Disk | Where-Object {$_.PartitionStyle -eq "GPT" -and $_.FriendlyName -eq "TempDBDisk"}}
    if ([string]::IsNullOrEmpty($VirtDisk)) {
        New-StoragePool -FriendlyName TempDBPool -StorageSubsystemFriendlyName "Windows Storage*" -PhysicalDisks $TempDisks -ResiliencySettingNameDefault Simple -ProvisioningTypeDefault Fixed -Verbose
        New-VirtualDisk -StoragePoolFriendlyName "TempDBPool" -FriendlyName "TempDBDisk" -ResiliencySettingName simple -UseMaximumSize -ProvisioningType Fixed
        Get-VirtualDisk -FriendlyName TempDBDisk | Get-Disk | Initialize-Disk -Passthru| New-Partition -DriveLetter $TempDriveletter -UseMaximumSize | Format-Volume -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel "SQL_TEMPDB" -Confirm:$false
        InfoLog("SQL Storage Volume - tempDB")
    }
}
catch {
    ErrorLog ($error[0].exception.message)
    exit
}

try {
    MountSingleVolume "tlogs01"
}
catch {
    ErrorLog ($error[0].exception.message)
    exit
}

try {
    MountSingleVolume "data01"
}
catch {
    ErrorLog ($error[0].exception.message)
    exit
}

try {
    MountSingleVolume "backup"
}
catch {
    ErrorLog ($error[0].exception.message)
    exit
}
