Param(
    [Parameter(Mandatory=$true)]
    [string] $AdUsername
  )

If ((Get-Service -Name 'MSSQLSERVER').status -ne "Running") {
    throw("SQL Service not running")
    exit 1
}

If ((Get-Service -Name 'SQLSERVERAgent').status -ne "Running") {
    throw("SQL Agent Service not running")
    exit 1
}
$sw = [diagnostics.stopwatch]::StartNew()
Import-Module SqlServer

$AGcheck = " IF SERVERPROPERTY ('IsHadrEnabled') = 1
BEGIN
SELECT
   AGC.name
 , RCS.replica_server_name
 , ARS.role_desc
 , AGL.dns_name
FROM
 sys.availability_groups_cluster AS AGC
  INNER JOIN sys.dm_hadr_availability_replica_cluster_states AS RCS
   ON
    RCS.group_id = AGC.group_id
  INNER JOIN sys.dm_hadr_availability_replica_states AS ARS
   ON
    ARS.replica_id = RCS.replica_id
  LEFT JOIN sys.availability_group_listeners AS AGL
   ON
    AGL.group_id = ARS.group_id
--WHERE
 --ARS.role_desc = 'PRIMARY'
END "

$wfcnodes = Get-ClusterNode | Sort-Object Name
$New_Replica = hostname
$AGreplicas = Invoke-Sqlcmd -query $AGcheck -ServerInstance $New_Replica | Sort-Object replica_server_name
$AGL = Get-ClusterResource | Where-Object { ($_.ResourceType -eq 'Network Name') -and ($_.OwnerGroup -eq ($AGreplicas.name | Get-Unique)) }

if (($AGreplicas.Count -eq 0) -or ($AGL.Count -eq 0)) {

    $ProgressPreference = "SilentlyContinue"
    $instanceID = Get-EC2InstanceMetadata -Category InstanceId
	$instancename = aws ec2 describe-tags --filters Name=resource-id,Values=$instanceID Name=key,Values=Name --query Tags[].Value --output text
	$instancetagAGname = aws ec2 describe-tags --filters Name=resource-id,Values=$instanceID Name=key,Values=AGName --query Tags[].Value --output text
    $instancetagAGLname = aws ec2 describe-tags --filters Name=resource-id,Values=$instanceID Name=key,Values=AGListenerName --query Tags[].Value --output text
	$instancetagwitnessname = aws ec2 describe-tags --filters Name=resource-id,Values=$instanceID Name=key,Values=FsxWitness --query Tags[].Value --output text

	$shortinstancetagnetbios = $instancename.SubString(0,($instancename.length-3))

	$clusterobjectsjson = aws ec2 describe-instances --filters "Name=tag-value,Values=$instancetagAGname" "Name=tag-value,Values=$shortinstancetagnetbios*" "Name=network-interface.addresses.private-ip-address,Values=*" --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,AGMode:Tags[?Key==`AGMode`]|[0].Value,PrivateDnsName:PrivateDnsName,State:State.Name, IP:NetworkInterfaces[0].PrivateIpAddresses[2], MainIP:NetworkInterfaces[0].PrivateIpAddress, SubnetId:SubnetId}'
    $clusterobjects = $clusterobjectsjson | ConvertFrom-Json
    $clusterobjects = $clusterobjects | Sort-Object -Property @{Expression={$_.IP}; Descending = $true}, @{Expression={[regex]::Matches($_.Name, "\d+(?!.*\d+)").value}}
	$nodes = $clusterobjects.Count
	$fswbasepath = "\\$($instancetagwitnessname)\share\"

	$aglnode = [System.Collections.ArrayList]@()
	$aglnodeCidr = [System.Collections.ArrayList]@()
	$aglnodeIP = [System.Collections.ArrayList]@()
	$agmode = [System.Collections.ArrayList]@()
	$subnetmask = [System.Collections.ArrayList]@()

    #Import-Module C:\SQL\ansible\common\Convert-Subnetmask.psm1
	
	for ($i=1; $i -le $nodes; $i++) {
		
		$null = $aglnode.Add($clusterobjects[$i-1].Name)
		$value = aws ec2 describe-subnets --filters ("Name=subnet-id,Values=$($clusterobjects[$i-1].SubnetId)") --query "Subnets[*].CidrBlock" --output text
		$null = $aglnodeCidr.Add($value)
		$null = $aglnodeIP.Add($clusterobjects[$i-1].IP.PrivateIPAddress)
		$null = $agmode.Add($clusterobjects[$i-1].AGMode)
		$prefixlengthnode = $aglnodeCidr[$i-1].Split("/")[1]
		# JS Instead of importing a whole module you can just use one of the sane solutions (engageant) from https://www.reddit.com/r/PowerShell/comments/81x324/shortest_script_challenge_cidr_to_subnet_mask/
		$value = ([ipaddress]([math]::Pow(2, 32) - [math]::Pow(2, (32 - $prefixlengthnode)))).IPAddressToString
		$null = $subnetmask.Add($value)
		
	}
    # $aglnode
	# $aglnodeCidr
	# $aglnodeIP
	# $prefixlengthnode
	# $subnetmask
}

if (($AGreplicas.Count -eq 0) -and ($wfcnodes.Count -eq $nodes)) {
    Write-Host("Start AG config on Primary")
    #create dummy database Dummy_[NodeName]
    $filepaths = Invoke-Sqlcmd -query "SELECT Default_Data_Path = serverproperty('InstanceDefaultDataPath'), Default_Log_Path = serverproperty('InstanceDefaultLogPath')" -ServerInstance $New_replica
    
    $create_dummy= " use master; if not exists (select 1 from sys.databases where name ='Dummy_"+$New_Replica +"') begin Create Database [Dummy_"+$New_Replica +"] on primary (
        Name =Dummy_" + $New_Replica +"_Data, FileName='"+$filepaths.Default_Data_Path+"Dummy_" + $New_Replica +".mdf'  ,  SIZE = 10MB, MAXSIZE =10MB) LOG ON 
        ( Name =Dummy_" + $New_Replica +"_Log, FileName='"+$filepaths.Default_Log_Path+"Dummy_" + $New_Replica +".ldf' , SIZE = 10MB, MAXSIZE = 20MB, FILEGROWTH =1MB) end "
                
    Invoke-Sqlcmd -query $create_dummy -ServerInstance $New_Replica

    Write-Host("Dummy DB created or exists on Primary")

    Get-ChildItem -Path $fswbasepath | Where-Object {$_.name -like ("Dummy_"+$New_Replica+"*") -and $_ -is [IO.FileInfo]} | Remove-Item -Force

    #Backup dummy DB to allow AG to be setup
    Backup-SqlDatabase -ServerInstance $New_Replica -Database ("Dummy_"+$New_Replica) -BackupFile ($fswbasepath+"Dummy_"+$New_Replica+".bak")
    Backup-SqlDatabase -ServerInstance $New_Replica -Database ("Dummy_"+$New_Replica) -BackupFile ($fswbasepath+"Dummy_"+$New_Replica+".trn") -BackupAction Log

    $DomainName = (Get-SSMParameterValue -Name "/Shared/AD/MicrosoftAD/RootDomain").Parameters.value
    #Create AG
    $Servers = [System.Collections.ArrayList]@()
    $Replicas = [System.Collections.ArrayList]@()
    #$ReplicaList = ''
    for ($i=1; $i -le $nodes; $i++) {
        $value = Get-Item "SQLSERVER:\SQL\$($aglnode[$i-1])\DEFAULT"
        $null = $Servers.Add($value)
        If ($agmode[$i-1].ToLower() -eq "sync") {
            $value = New-SqlAvailabilityReplica `
                -Name $aglnode[$i-1] `
                -EndpointUrl "TCP://$($aglnode[$i-1]).$($DomainName.ToLower()):5022" `
                -FailoverMode "Automatic" `
                -AvailabilityMode "SynchronousCommit" `
                -ConnectionModeInPrimaryRole AllowAllConnections `
                -ConnectionModeInSecondaryRole AllowReadIntentConnectionsOnly `
                -SeedingMode Automatic `
                -ReadonlyRoutingConnectionUrl "TCP://$($aglnode[$i-1]).$($DomainName.ToLower()):1433" `
                -AsTemplate `
                -Version ($Servers[$i-1].Version)
        } elseif ($agmode[$i-1].ToLower() -eq "async") {
            $value = New-SqlAvailabilityReplica `
                -Name $aglnode[$i-1] `
                -EndpointUrl "TCP://$($aglnode[$i-1]).$($DomainName.ToLower()):5022" `
                -FailoverMode "Manual" `
                -AvailabilityMode "AsynchronousCommit" `
                -ConnectionModeInPrimaryRole AllowAllConnections `
                -ConnectionModeInSecondaryRole AllowNoConnections `
                -SeedingMode Automatic `
                -AsTemplate `
                -Version ($Servers[$i-1].Version)
        }
        $null = $Replicas.Add($value)
        $checkHADR = $Servers[$i-1].Endpoints | Where-Object {$_.Name -eq 'Hadr_endpoint'}
        if ($checkHADR.count -eq 0) {
            $endpoint = New-SqlHADREndpoint -InputObject $Servers[$i-1] -Name "Hadr_endpoint" -Owner $AdUsername -Port 5022 -EncryptionAlgorithm Aes -Encryption Require
            #ensure HADR is started
            Set-SqlHADREndpoint -InputObject $endpoint -State Started
        } else {
            Set-SqlHADREndpoint -Path "SQLSERVER:\SQL\$($aglnode[$i-1])\DEFAULT\Endpoints\Hadr_endpoint" -Owner $AdUsername -Port 5022 -EncryptionAlgorithm Aes -Encryption Require -State Started
        }
        #$ReplicaList = $ReplicaList + '$Replicas['+($i-1)+'],'
    }
    #$ReplicaList = $ReplicaList -replace ".$" #removes last character
    $Error.clear()
    New-SqlAvailabilityGroup -Name $instancetagAGname -InputObject $New_Replica -AvailabilityReplica $Replicas -Database Dummy_$New_Replica
    if ($Error){
        Write-Host($_)
		throw("failed to created AG")
		exit 1
	}
    
    for ($i=2; $i -le $nodes; $i++) {
        $Error.clear()
        Restore-SqlDatabase -Database ("Dummy_"+$New_Replica) -BackupFile ($fswbasepath+"Dummy_"+$New_Replica+".bak") -ServerInstance $aglnode[$i-1] -NoRecovery
        Restore-SqlDatabase -Database ("Dummy_"+$New_Replica) -BackupFile ($fswbasepath+"Dummy_"+$New_Replica+".trn") -ServerInstance $aglnode[$i-1] -RestoreAction Log -NoRecovery
        If ($Error) {
            Write-Host($_)
            throw($aglnode[$i-1] + " failed to restore dummy DB")
		    exit 1
        }
        $Error.clear()
        Join-SqlAvailabilityGroup -InputObject $Servers[$i-1] -Name $instancetagAGname
        If ($Error) {
            Write-Host($_)
            throw($aglnode[$i-1] + " failed to join to AG")
		    exit 1
        }
        $Error.clear()
        Add-SqlAvailabilityDatabase -Path ("SQLSERVER:\SQL\$($aglnode[$i-1])\DEFAULT\AvailabilityGroups\"+$instancetagAGname) -Database ("Dummy_"+$New_Replica)
        If ($Error) {
            Write-Host($_)
            throw($aglnode[$i-1] + " failed to add dummy DB to AG")
		    exit 1
        }
    }

    Get-ClusterGroup | Where-Object{$_.Name -eq $instancetagAGname} | ForEach-Object {$_.autofailbacktype = 0}

    $timer = ($sw.elapsed | select TotalSeconds).TotalSeconds
	Write-Host("Elapsed time for AG $instancetagAGname is $timer seconds")
    $sw.Reset()
    $sw.Start()

} else {
    Write-Host("AG already created")
}

if ($AGL.Count -eq 0) {
    
    $PrimaryPath = "SQLSERVER:\SQL\$New_Replica\DEFAULT\AvailabilityGroups\$instancetagAGname"
    
    $StaticIP = [System.Collections.ArrayList]@()
    for ($i=1; $i -le $nodes; $i++) {
        If (-not([string]::IsNullOrEmpty($aglnodeIP[$i-1]))) {
            $null = $StaticIP.Add(@{ IPSubnet=($aglnodeIP[$i-1]+"/"+$subnetmask[$i-1]); Cidr=($aglnodeCidr[$i-1])})
        }
    }
    $Error.clear()
    New-SqlAvailabilityGroupListener -Name $instancetagAGLname -Path $PrimaryPath -StaticIp $StaticIP.IPSubnet -Port 1433
    If (!$Error) {
        for ($i=1; $i -le $StaticIP.count; $i++) {
            $value = $instancetagAGname+"_"+$StaticIP[$i-1].IPSubnet.Split("/")[0]
            $resourceName = Get-ClusterResource | Where-Object {$_.ResourceType -eq 'IP Address' -and ($_.Name -eq $value)}
            if ($resourceName.Count -eq 1) {
                $aglowners = [System.Collections.ArrayList]@()
		        $j = 0
		        foreach ($element in $aglnode) { 
			        if ($aglnodeCidr[$j] -eq $StaticIP[$i-1].Cidr) {
				        $null = $aglowners.Add($element)
			        }
			        ++$j
		        }
                Get-ClusterResource -Name $resourceName.Name | Set-ClusterOwnerNode -Owners $aglowners
                Write-Host("AGL IP $($resourceName.Name) ownernode updated")
            }
        }
        #Set Config for the listener
        $Listener = Get-ClusterResource | Where-Object{$_.ResourceType -eq "Network Name" -and $_.Name -eq ($instancetagAGname+"_"+$instancetagAGLname)}
        If ($Listener.Count -eq 1) {
            $Listener | Set-ClusterParameter HostRecordTTL 60
            $Listener | Set-ClusterParameter RegisterAllProvidersIP 0
            Stop-ClusterResource -Name $instancetagAGname
            Stop-ClusterResource -Name $Listener.Name
            Start-Sleep -Seconds 30
            Start-ClusterResource -Name $Listener.Name
            Start-ClusterResource -Name $instancetagAGname
            Write-Host("AGL config updated and restarted")
        }

        #Set the ReadOnlyRoutingList
        $ReadOnlyReplicas = [System.Collections.ArrayList]@()
        $SyncReplicas = (Get-Item "$($PrimaryPath)\AvailabilityReplicas").Collection | Where-Object{$_.RollupSynchronizationState -eq "Synchronized"}
        for ($i=1; $i -le $SyncReplicas.Count; $i++) {
            $null = $ReadOnlyReplicas.Add($SyncReplicas.Name[$i-1])
        }

        for ($i=1; $i -le $SyncReplicas.Count; $i++) {
            $RoutingList = $ReadOnlyReplicas.Clone() 
            $null = $RoutingList.Remove($ReadOnlyReplicas[$i-1])
            $null = $RoutingList.Add($ReadOnlyReplicas[$i-1])
            $Error.clear()
            $Replica = Get-Item "$($PrimaryPath)\AvailabilityReplicas\$($ReadOnlyReplicas[$i-1])"
            Set-SqlAvailabilityReplica -ReadOnlyRoutingList $RoutingList -InputObject $Replica
            If (!$Error) {
                Write-Host("ReadOnlyRoutingList Updated for $($ReadOnlyReplicas[$i-1])")
            } else {
                Write-Host($_)
			    throw("failed to update ReadOnlyRoutingList for $($ReadOnlyReplicas[$i-1])")
			    exit 1
            }
        }
        # $query = " USE [master]
        # GO
        # ALTER AVAILABILITY GROUP ["+$instancetagAGname+"]
        # MODIFY REPLICA ON N'"+$aglnode[0]+"' WITH (PRIMARY_ROLE(READ_ONLY_ROUTING_LIST = (N'"+$aglnode[1]+"',N'"+$aglnode[0]+"')))
        # GO
        # USE [master]
        # GO
        # ALTER AVAILABILITY GROUP ["+$instancetagAGname+"]
        # MODIFY REPLICA ON N'"+$aglnode[1]+"' WITH (PRIMARY_ROLE(READ_ONLY_ROUTING_LIST = (N'"+$aglnode[0]+"',N'"+$aglnode[1]+"')))
        # GO "
        # $readlist = Invoke-Sqlcmd -query $query -ServerInstance $New_Replica
        # If ([string]::IsNullOrEmpty($readlist )) {
        #     Write-Host("ReadOnlyRoutingList Updated for primary and secondary nodes")
        # }
        $timer = ($sw.elapsed | select TotalSeconds).TotalSeconds
	    Write-Host("Elapsed time for AGL $instancetagAGLname is $timer seconds")
    } else {
        Write-Host($_)
        throw("failed to create AGL")
        exit 1
    }

} else {
    Write-Host("AGL already created")
}
$sw.stop()