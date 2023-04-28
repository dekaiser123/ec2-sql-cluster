Param(
    [Parameter(Mandatory=$true)]
    [string] $AdUsername,
    [Parameter(Mandatory=$false)] #make this optional so it can be run as standalone
    [string] $CW
  )

#Source - https://gist.github.com/indented-automation/1c319fe8c7abadfe509cb4205eeb5720
enum UserRight {
    SeAssignPrimaryTokenPrivilege        # Replace a process level token
    SeAuditPrivilege                     # Generate security audits
    SeBackupPrivilege                    # Back up files and directories
    SeBatchLogonRight                    # Log on as a batch job
    SeChangeNotifyPrivilege              # Bypass traverse checking
    SeCreateGlobalPrivilege              # Create global objects
    SeCreatePagefilePrivilege            # Create a pagefile
    SeCreatePermanentPrivilege           # Create permanent shared objects
    SeCreateSymbolicLinkPrivilege        # Create symbolic links
    SeCreateTokenPrivilege               # Create a token object
    SeDebugPrivilege                     # Debug programs
    SeDenyBatchLogonRight                # Deny log on as a batch job
    SeDenyInteractiveLogonRight          # Deny log on locally
    SeDenyNetworkLogonRight              # Deny access to this computer from the network
    SeDenyRemoteInteractiveLogonRight    # Deny log on through Remote Desktop Services
    SeDenyServiceLogonRight              # Deny log on as a service
    SeEnableDelegationPrivilege          # Enable computer and user accounts to be trusted for delegation
    SeImpersonatePrivilege               # Impersonate a client after authentication
    SeIncreaseBasePriorityPrivilege      # Increase scheduling priority
    SeIncreaseQuotaPrivilege             # Adjust memory quotas for a process
    SeIncreaseWorkingSetPrivilege        # Increase a process working set
    SeInteractiveLogonRight              # Allow log on locally
    SeLoadDriverPrivilege                # Load and unload device drivers
    SeLockMemoryPrivilege                # Lock pages in memory
    SeMachineAccountPrivilege            # Add workstations to domain
    SeManageVolumePrivilege              # Perform volume maintenance tasks
    SeNetworkLogonRight                  # Access this computer from the network
    SeProfileSingleProcessPrivilege      # Profile single process
    SeRelabelPrivilege                   # Modify an object label
    SeRemoteInteractiveLogonRight        # Allow log on through Remote Desktop Services
    SeRemoteShutdownPrivilege            # Force shutdown from a remote system
    SeRestorePrivilege                   # Restore files and directories
    SeSecurityPrivilege                  # Manage auditing and security log
    SeServiceLogonRight                  # Log on as a service
    SeShutdownPrivilege                  # Shut down the system
    SeSyncAgentPrivilege                 # Synchronize directory service data
    SeSystemEnvironmentPrivilege         # Modify firmware environment values
    SeSystemProfilePrivilege             # Profile system performance
    SeSystemtimePrivilege                # Change the system time
    SeTakeOwnershipPrivilege             # Take ownership of files or other objects
    SeTcbPrivilege                       # Act as part of the operating system
    SeTimeZonePrivilege                  # Change the time zone
    SeTrustedCredManAccessPrivilege      # Access Credential Manager as a trusted caller
    SeUndockPrivilege                    # Remove computer from docking station
}

function Grant-UserRight {
    <#
    .SYNOPSIS
        Grant a right or set of rights to an account.
    .DESCRIPTION
        Grant a right or set of rights to an account.
    .INPUTS
        System.String
    .EXAMPLE
        whoami | Grant-UserRight -Right SeBatchLogonRight
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([Void])]
    param (
        # Grant a right to the specified identity.
        [Parameter(Mandatory = $true, Position = 1,  ValueFromPipeline = $true)]
        [System.Security.Principal.NTAccount]$Identity,

        # The right or rights which should be granted to each identity.
        [Parameter(Mandatory = $true)]
        [UserRight[]]$Right
    )

    begin {
        $params = @{
            Path      = [Environment]::GetEnvironmentVariable('TEMP', 'Machine')
            ChildPath = [System.IO.Path]::GetRandomFileName()
        }
        $path = Join-Path @params

        secedit.exe /export /areas USER_RIGHTS /cfg $path > $null

        if (Test-Path $path) {
            $userRights = New-Object System.Collections.Generic.Dictionary"[String,String[]]"
            foreach ($rightToGrant in $Right) {
                $userRights.$rightToGrant = @()
            }
            Get-Content $path | Where-Object { $_ -match '^(?<Name>Se\S+) = (?<SidList>.+)$' -and $matches.Name -in $Right } | ForEach-Object {
                $userRights.($matches.Name) = @($matches.SidList.Split(','))
            }
        }
    }

    process {
        try {
            $sid = $Identity.Translate([System.Security.Principal.SecurityIdentifier])

            foreach ($rightToGrant in $Right) {
                if ($userRights[$rightToGrant] -contains "*$sid") {
                    Write-Verbose ('The right {0} has already been assigned to {1}' -f $matches.Name, $Identity)
                } else {
                    $userRights[$rightToGrant] += "*$sid"
                }
            }
        } catch {
            Write-Error -ErrorRecord $_
        }
    }

    end {
        $content = '[Unicode]',
            'Unicode=yes',
            '[Version]',
            'signature="$CHICAGO$"',
            'Revision=1',
            '[Privilege Rights]'
        $content += $Right | ForEach-Object {
            '{0} = {1}' -f $_, ($userRights[$_] -join ',')
        }
        $content | Write-Debug

        Set-Content $path -Value $content -Encoding Unicode -WhatIf:$false

        if ($pscmdlet.ShouldProcess('Setting user rights')) {
            secedit.exe /configure /db 'secedit.sdb' /areas USER_RIGHTS /cfg $path > $null
            Remove-Item 'secedit.sdb'
            Remove-Item $path

            # Basic parsing of the log file
            if (Test-Path $env:WINDIR\security\logs\scesrv.log) {
                $getErrorMessage = $false
                Get-Content $env:WINDIR\security\logs\scesrv.log | Foreach-Object {
                    if ($_ -match '^Error (\d+):') {
                        $errorCode = [Int]$matches[1]
                        $getErrorMessage = $true
                    } elseif ($getErrorMessage) {
                        $getErrorMessage = $false
                        Write-Error -Exception (New-Object System.ComponentModel.Win32Exception($errorCode, $_.Trim()))
                    } else {
                        Write-Verbose $_
                    }
                }
            }
        } else {
            Remove-Item $path -WhatIf:$false
        }
    }
}

$Error.clear()
Grant-UserRight $AdUsername -Right "SeBatchLogonRight"

if(!$Error) {
    $message = "SQLAdmins Added and SrvAcc SetBatchLogonRight"
} else {
    $message = "ERR: SrvAcc not in local admin group, add then rerun Grant-UserRight script"
}

Write-Host($message)

if (-not [string]::IsNullOrEmpty($CW)) {
    Invoke-Expression ($CW + " -LogString `"$message`"")
}