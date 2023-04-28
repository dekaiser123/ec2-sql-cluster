$ipv6_check = Get-NetAdapterBinding -ComponentID ms_tcpip6

if ($ipv6_check -ne $null) {
    Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6
}

#Do not disable ipv6 completely https://msunified.net/2016/05/25/how-to-set-ipv4-as-preferred-ip-on-windows-server-using-powershell/
$ipv4check = get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\" -Name "DisabledComponents" -ErrorAction SilentlyContinue

if ([string]::IsNullOrEmpty($ipv4check)) {
    New-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\" -Name "DisabledComponents" -Value 0x20 -PropertyType "Dword"
    Write-Host "Restart Computer for settings to take affect"
} else {
    if ($ipv4check.DisabledComponents -ne 32) {
        #Set IPv4 to be preferred - Reboot required after this change
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\" -Name "DisabledComponents" -Value 0x20
        Write-Host "Restart Computer for settings to take affect"
    }
}
#To Completely disable ipv6 - Reboot required after this change
#New-ItemProperty “HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\” -Name “DisabledComponents” -Value 0xffffffff -PropertyType “DWord"