param(
    [Parameter(Mandatory = $false)][string]$driveletter,#= "T"
    [Parameter(Mandatory = $false)][int]$filecount
)

$tempDBfiles = (Get-ChildItem -Path ($driveletter+":\") -recurse | Where-Object {$_ -is [IO.FileInfo]}).Count
#$tempDBfiles = 0

If ($tempDBfiles -eq 0) {

    Import-Module sqlserver

    $computer = hostname
    #$cores = (Get-CimInstance –ClassName Win32_Processor).NumberOfLogicalProcessors
    $filecount = $filecount + 1
    $disksize = (Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DeviceID -like ($driveletter+'*')} | Select-Object -Property DeviceID,@{'Name' = 'FreeSpace_GB'; Expression= { [int]($_.FreeSpace / 1GB) }}).FreeSpace_GB

    #$disksize = [math]::floor($disksize / 10) * 10

    $VAR1 = "DriveSize="+$disksize
    $VAR2 = "Files="+$filecount
    $VAR3 = "DriveLetter="+$driveletter

    Invoke-Sqlcmd -InputFile "C:\SQL\ansible\sql_ag\sql_maint_scripts\MoveTempDB.sql" -ServerInstance $computer -Variable $VAR1, $VAR2, $VAR3

    $ServiceName = 'MSSQLSERVER'
    Stop-Service -Name $ServiceName -Force 
    while ((Get-Service -Name $ServiceName).status -ne "Stopped") {
        Start-Sleep -Seconds 10
    }
    Get-ChildItem -Path "C:\Program Files\Microsoft SQL Server" -recurse | Where-Object {$_.name -like "temp*" -and $_ -is [IO.FileInfo]} | Remove-Item -Force
    Start-Service -Name $ServiceName
    Restart-service -Name 'SQLSERVERAgent' -Force

    Write-Host("TempDB files moved old files deleted")

} else {
    Write-Host("TempDB files already moved")
}