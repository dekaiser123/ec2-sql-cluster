$uacPath = "HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system"
$valueExists = (Get-Item $uacPath -EA Ignore).Property -contains "EnableLUA"
if($valueExists) {
$uac = Get-ItemProperty -Path $uacPath -Name "EnableLUA"
$checkuac = $uac.EnableLUA
if($checkuac -eq 1){
Set-ItemProperty -Path $uacPath -Name "EnableLUA" -Value 0 -Force
}
} else {
New-ItemProperty -Path $uacPath -Name "EnableLUA" -PropertyType DWord -Value 0 -Force
}
Set-ItemProperty $uacPath -Name "ConsentPromptBehaviorAdmin" -Value 00000000 -Force
Write-Host "User Access Control (UAC) has been disabled." -ForegroundColor Green  