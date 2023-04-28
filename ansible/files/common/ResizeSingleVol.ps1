param(
    [Parameter(Mandatory = $false)][string]$tempDB = "T:\"
)

Get-Disk | ForEach-Object { Update-Disk -Number $_.Number }

(Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DeviceID -notlike ($tempDB[0]+'*')}) | ForEach-Object {
    $drive_letter = $_.DeviceID[0]
    #Write-Host($drive_letter)
    $size = Get-PartitionSupportedSize -DriveLetter $drive_letter
    $sizeMax_GB = [math]::Round($size.SizeMax / 1GB)
    $currsize_GB = [math]::Round((Get-Partition -DriveLetter $drive_letter).size / 1GB)
    If ($sizeMax_GB -gt $currsize_GB) {
        Resize-Partition -DriveLetter $drive_letter -Size $size.SizeMax
    }
}