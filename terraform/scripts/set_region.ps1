
$file = "C:\ProgramData\Amazon\EC2-Windows\Launch\Sysprep\Unattend.xml"
$doc = [xml](Get-Content $file)
$settings = $doc.unattend.settings | Where-Object { $_.Pass -eq "oobeSystem" } | Select-Object -ExpandProperty component | Where-Object { $_.name -eq "Microsoft-Windows-International-Core" }
$settings.InputLocale = 'en-AU'
$settings.SystemLocale = 'en-AU'
$settings.UserLocale = 'en-AU'
$settings
$timezone = $doc.unattend.settings | Where-Object { $_.Pass -eq "specialize" } | Select-Object -ExpandProperty component | Where-Object { $_.name -eq "Microsoft-Windows-Shell-Setup" }
$timezone.TimeZone = 'AUS Eastern Standard Time'
$timezone
$oobetimezone = $doc.unattend.settings | Where-Object { $_.Pass -eq "oobeSystem" } | Select-Object -ExpandProperty component | Where-Object { $_.name -eq "Microsoft-Windows-Shell-Setup" }
$oobetimezone.TimeZone = 'AUS Eastern Standard Time'
$oobetimezone
$doc.Save($file)