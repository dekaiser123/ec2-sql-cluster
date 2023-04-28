param (
	[Parameter(Mandatory=$true)][string]$SecondaryServer
)

Import-Module Sqlserver
function TestConnect($AGL) {
	
	$AGLName = $AGL.Name
	if ($AGLName.Count -eq 1) {
		Test-NetConnection -ComputerName $AGLName -Port $AGL.PortNumber
	} else {
		for ($i=1; $i -le $AGLName.Count; $i++) {
			Test-NetConnection -ComputerName $AGLName[$i-1] -Port $AGL.PortNumber[$i-1]
		}
	}
	
}

function TestAGL($AG, $Server) {
	
	$AGName = $AG.Name
	if ($AGName.Count -eq 1) {
		$Listener = Get-ChildItem "SQLSERVER:\Sql\$Server\DEFAULT\AvailabilityGroups\$AGName\AvailabilityGroupListeners"
		TestConnect $Listener
	} else {
		for ($i=1; $i -le $AGName.Count; $i++) {
			$AGName2 = $AGName[$i-1]
			$Listener = Get-ChildItem "SQLSERVER:\Sql\$Server\DEFAULT\AvailabilityGroups\$AGName2\AvailabilityGroupListeners"
			TestConnect $Listener
		}
	}
	
}
function TestFailover($AG, $FailToServer) {
	
	$AGName = $AG.Name
	if ($AGName.Count -eq 1) {
		Switch-SqlAvailabilityGroup -Path "SQLSERVER:\Sql\$FailToServer\DEFAULT\AvailabilityGroups\$AGName"
	} else {
		for ($i=1; $i -le $AGName.Count; $i++) {
			$AGName2 = $AGName[$i-1]
			Switch-SqlAvailabilityGroup -Path "SQLSERVER:\Sql\$FailToServer\DEFAULT\AvailabilityGroups\$AGName2"
		}
	}
	
}

$svr = hostname
$AGPath = "sqlserver:\SQL\$svr\DEFAULT\AvailabilityGroups"
$AGDetails = Get-ChildItem -path $AGPath | select-object Name, PrimaryReplicaServerName
$PrimaryServer = $AGDetails.PrimaryReplicaServerName
$Unhealthy = 0

If ($PrimaryServer -eq $svr) {
	Write-Host("Start HealthChecks")

	$AGCheck = Get-ChildItem "SQLSERVER:\Sql\$svr\DEFAULT\AvailabilityGroups" | Test-SqlAvailabilityGroup
	Write-Host($AGCheck | Out-String)
	
	$AGCheck | Where-Object { $_.HealthState -ne "Healthy" } | Foreach-Object {$Unhealthy = $Unhealthy + 1}

	$AGName1 = $AGDetails.Name
	if ($AGName1.Count -eq 1) {
		$ReplicaCheck = Get-ChildItem "SQLSERVER:\Sql\$svr\DEFAULT\AvailabilityGroups\$AGName1\AvailabilityReplicas" | Test-SqlAvailabilityReplica
		Write-Host($ReplicaCheck | Out-String)
	
		$ReplicaCheck | Where-Object { $_.HealthState -ne "Healthy" } | Foreach-Object {$Unhealthy = $Unhealthy + 1}

		$DBCheck = Get-ChildItem "SQLSERVER:\Sql\$svr\DEFAULT\AvailabilityGroups\$AGName1\DatabaseReplicaStates" | Test-SqlDatabaseReplicaState
		Write-Host($DBCheck | Out-String)
	
		$DBCheck | Where-Object { $_.HealthState -ne "Healthy" } | Foreach-Object {$Unhealthy = $Unhealthy + 1}
	} else {
		for ($i=1; $i -le $AGName1.Count; $i++) {
			$AGName3 = $AGName1[$i-1]
			$ReplicaCheck = Get-ChildItem "SQLSERVER:\Sql\$svr\DEFAULT\AvailabilityGroups\$AGName3\AvailabilityReplicas" | Test-SqlAvailabilityReplica
			Write-Host($ReplicaCheck | Out-String)
	
			$ReplicaCheck | Where-Object { $_.HealthState -ne "Healthy" } | Foreach-Object {$Unhealthy = $Unhealthy + 1}

			$DBCheck = Get-ChildItem "SQLSERVER:\Sql\$svr\DEFAULT\AvailabilityGroups\i$AGName3\DatabaseReplicaStates" | Test-SqlDatabaseReplicaState
			Write-Host($DBCheck | Out-String)
	
			$DBCheck | Where-Object { $_.HealthState -ne "Healthy" } | Foreach-Object {$Unhealthy = $Unhealthy + 1}
		}
	}
	
} else {
	throw("Executed in Secondary node $svr, change server to $PrimaryServer")
    exit 1
}

If ($Unhealthy -eq 0) {
	TestAGL $AGDetails $svr
	TestFailover $AGDetails $SecondaryServer
	Start-Sleep -s 180
	$AGPath = "sqlserver:\SQL\$SecondaryServer\DEFAULT\AvailabilityGroups"
	$AGDetails = Get-ChildItem -path $AGPath | select-object Name, PrimaryReplicaServerName
	$FailedOver = $AGDetails.PrimaryReplicaServerName
	If ($FailedOver -eq $SecondaryServer) {
		Write-Host("-----------------------------------------------------------------")
		Write-Host("-----------------------FAILOVER SUCCESSFUL-----------------------")
		Write-Host("-----------------------------------------------------------------")
		TestAGL $AGDetails $SecondaryServer
	} else {
		throw("Failover Unsuccessful, server $FailedOver not equal to $SecondaryServer")
		exit 1
	}
} else {
	throw("Unhealthy AG elements")
    exit 1
}