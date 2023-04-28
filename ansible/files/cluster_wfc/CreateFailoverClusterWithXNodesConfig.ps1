$clustercheck = (get-cluster -ErrorAction SilentlyContinue).name
if ([string]::IsNullOrEmpty($clustercheck)) {

	$sw = [diagnostics.stopwatch]::StartNew()
	
	$ProgressPreference = "SilentlyContinue"
	#$AWS_AVAIL_ZONE = (curl -UseBasicParsing http://169.254.169.254/latest/meta-data/placement/availability-zone).Content
	#$AWS_REGION = $AWS_AVAIL_ZONE.Substring(0, $AWS_AVAIL_ZONE.length - 1)
	#$AWS_INSTANCE_ID = (curl -UseBasicParsing http://169.254.169.254/latest/meta-data/instance-id).Content
    $instanceID = Get-EC2InstanceMetadata -Category InstanceId
	$instancename = aws ec2 describe-tags --filters Name=resource-id,Values=$instanceID Name=key,Values=Name --query Tags[].Value --output text
	#$instancetagrole = aws ec2 describe-tags --filters Name=resource-id,Values=$instanceID Name=key,Values=Role --query Tags[].Value --output text
	$instancetagclustername = aws ec2 describe-tags --filters Name=resource-id,Values=$instanceID Name=key,Values=ClusterName --query Tags[].Value --output text
	$instancetagwitnessname = aws ec2 describe-tags --filters Name=resource-id,Values=$instanceID Name=key,Values=FsxWitness --query Tags[].Value --output text

	$shortinstancetagnetbios = $instancename.SubString(0,($instancename.length-3))

	$clusterobjectsjson = aws ec2 describe-instances --filters "Name=tag-value,Values=$instancetagclustername" "Name=tag-value,Values=$shortinstancetagnetbios*" "Name=network-interface.addresses.private-ip-address,Values=*" --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,PrivateDnsName:PrivateDnsName,State:State.Name, IP:NetworkInterfaces[0].PrivateIpAddresses[1], MainIP:NetworkInterfaces[0].PrivateIpAddress, SubnetId:SubnetId}'
	$clusterobjects = $clusterobjectsjson | ConvertFrom-Json
	$clusterobjects = $clusterobjects | Sort-Object -Property @{Expression={$_.IP}; Descending = $true}, @{Expression={[regex]::Matches($_.Name, "\d+(?!.*\d+)").value}}
	$nodes = $clusterobjects.Count
	$fswbasepath = "\\$($instancetagwitnessname)\share\"
	#$clusterwitnesspath = "\\$($instancetagwitnessname)\d$\share"
	$fswlocation = $fswbasepath + $instancetagclustername
	#Need to precreate the CNO named folder under the default share folder created by fsx
	if ((Test-Path $fswlocation) -eq $false) {
		$Error.clear()
		mkdir $fswlocation
		If (!$Error) {
			Write-Host("FSx cluster folder created")
		} else {
			throw("failed to create cluster folder, check permissions and path")
			exit 1
		}
	}

	$clusternode = [System.Collections.ArrayList]@()
	$clusternodeCidr = [System.Collections.ArrayList]@()
	$clusternodeIP = [System.Collections.ArrayList]@()
	$subnetmask = [System.Collections.ArrayList]@()
	
	#Import-Module C:\SQL\ansible\common\Convert-Subnetmask.psm1
	
	for ($i=1; $i -le $nodes; $i++) {
		
		$null = $clusternode.Add($clusterobjects[$i-1].Name)
		$value = aws ec2 describe-subnets --filters ("Name=subnet-id,Values=$($clusterobjects[$i-1].SubnetId)") --query "Subnets[*].CidrBlock" --output text
		$null = $clusternodeCidr.Add($value)
		$null = $clusternodeIP.Add($clusterobjects[$i-1].IP.PrivateIPAddress)
		$prefixlengthnode = $clusternodeCidr[$i-1].Split("/")[1]
		# JS Instead of importing a whole module you can just use one of the sane solutions (engageant) from https://www.reddit.com/r/PowerShell/comments/81x324/shortest_script_challenge_cidr_to_subnet_mask/
		$value = ([ipaddress]([math]::Pow(2, 32) - [math]::Pow(2, (32 - $prefixlengthnode)))).IPAddressToString
		$null = $subnetmask.Add($value)
		
	}
	
	# $clusternode
	# $clusternodeCidr
	# $clusternodeIP
	# $prefixlengthnode
	# $subnetmask
	
	$scriptblock = {
                    
		try {
			C:\SQL\ansible\cluster_wfc\PrestageCO.ps1 | Out-Null
		}
		catch {
			Write-Host($_)
		}
	}

	$netbios = hostname
	$DomainName = (Get-SSMParameterValue -Name "/Shared/AD/MicrosoftAD/RootDomain").Parameters.value
	$DomainJoinUsername = (Get-SSMParameterValue -Name "/Shared/AD/DomainJoin/ServiceAccount").Parameters.value
	$DomainJoinPassword = (Get-SSMParameterValue -Name "/Shared/AD/DomainJoin/Password" -WithDecryption $true).Parameters.value | ConvertTo-SecureString -AsPlainText -Force
	$JoinADAccountwithDomain = ($DomainName -split "\.")[0] + "\" + $DomainJoinUsername
	$credential = New-Object System.Management.Automation.PSCredential($JoinADAccountwithDomain, $DomainJoinPassword) -ErrorAction Stop

	#Add Join Domain to Local Group  Administrators
	if ((Get-LocalGroupMember -Group Administrators|where-Object {$_.ObjectClass -match "User" -and $_.Name -eq $JoinADAccountwithDomain}).count -eq 0){
		Add-LocalGroupMember -Group administrators -Member $DomainJoinUsername}

	$so = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
	$session = New-PSSession -ComputerName $netbios -Credential $credential -SessionOption $so -UseSSL -Authentication CredSSP
	Invoke-Command -Session $session -ScriptBlock $scriptblock

	#Remove Join Domain to Local Group  Administrators
	if ((Get-LocalGroupMember -Group Administrators|where-Object {$_.ObjectClass -match "User" -and $_.Name -eq $JoinADAccountwithDomain}).count -eq 1){
		Remove-LocalGroupMember -Group administrators -Member $DomainJoinUsername}
		
	start-sleep -Seconds 90
	
	$Error.clear()
	Test-Cluster -Node $clusternode
	if (!$Error){
		Write-Host("cluster validated, nodes reachable")
	} else {
		Write-Host($_)
		throw("failed to validated cluster")
		exit 1
	}

	$Primary = $clusternode[0] + "." + $DomainName.ToLower()
	$StaticIP = $clusternodeIP[0]
	
	$Error.clear()
	New-Cluster -Name $instancetagclustername -node $Primary -StaticAddress $StaticIP -NoStorage -Force
	if (!$Error){
		get-cluster -Name $instancetagclustername -Domain ($DomainName -split "\.")[0]
		if ($Error -ne $null) {
			throw("no cluster found")
			exit 1
		}
		Write-Host("Cluster created successfully")
	} else {
		Write-Host($_)
		throw("failed to created cluster")
		exit 1
	}
	
	$ClusterResource = [System.Collections.ArrayList]@()
	$defaultIPName = (Get-ClusterResource | Where-Object { $_.ResourceType -eq 'IP Address' } | Get-ClusterParameter -Name Address | Where-Object { $_.Value -eq $clusternodeIP[0] }).ClusterObject.Name
	if ($defaultIPName -eq "Cluster IP Address") {
		(Get-ClusterResource -Name "Cluster IP Address").Name = "Cluster IP Node01"
		$null = $ClusterResource.Add(@{ ResourceName=("Cluster IP Node01"); PointerIndex=(0)})
	} else {
		throw("failed to find primary cluster IP")
		exit 1
	}
	
	#Add nodes one at a time to maintain cluster network number alignment
	for ($i=2; $i -le $nodes; $i++) {
		
		$Error.clear()
		If ((Get-ClusterNode | where-object { $_.Name -match $clusternode[$i-1]}).count -eq 0) {
			Write-Host("Add node $i")
			add-clusterNode -Name $clusternode[$i-1]
		}
		
		If (!$Error) {
			$exist = (Get-ClusterResource | Where-Object { $_.ResourceType -eq 'IP Address' } | Get-ClusterParameter -Name Address | Where-Object { $_.Value -eq $clusternodeIP[$i-1] }).Count
			If ($exist -eq 0 -and -not([string]::IsNullOrEmpty($clusternodeIP[$i-1]))) {
				start-sleep -Seconds 30
				Write-Host("Add staticIP for node $i")
				$resourceName = "Cluster IP Node"+([string]$i).PadLeft(2,'0')
				Get-Cluster | Add-ClusterResource -Name $resourceName -Group 'Cluster Group' -ResourceType 'IP Address'
				Get-ClusterResource -Name $resourceName | Set-ClusterParameter -Multiple @{ Address = $clusternodeIP[$i-1]; Network = "Cluster Network $i"; SubnetMask = $subnetmask[$i-1] }
				$dependencyExpression = (Get-Cluster | Get-ClusterResourceDependency -Resource 'Cluster Name').DependencyExpression
				if ($dependencyExpression -match '^\((.*)\)$') {
					$dependencyExpression = $Matches[1] + " or [$resourceName]"
				}
				else {
					$dependencyExpression = $dependencyExpression + " or [$resourceName]"
				}
				Get-Cluster | Set-ClusterResourceDependency -Resource 'Cluster Name' -Dependency $dependencyExpression
				# Without this, it won't start automatically on first try
				(Get-Cluster | Get-ClusterResource -Name $resourceName).PersistentState = 1
				#start-sleep -Seconds 30
				#Get-ClusterResource -Name $resourceName | Set-ClusterOwnerNode -Owners $clusternode[$i-1]
				$null = $ClusterResource.Add(@{ ResourceName=($resourceName); PointerIndex=($i-1)})
			}
		} else {
			Write-Host($_)
			throw("failed to add node $i")
			exit 1
		}
		start-sleep -Seconds 30
	}
	
	# If ((Get-ClusterNode).count -gt 1) {
	# 	Get-ClusterResource -Name "Cluster IP Node01" | Set-ClusterOwnerNode -Owners $clusternode[0]
	# }

	for ($i=1; $i -le $ClusterResource.Count; $i++) {
		$clusterowners = [System.Collections.ArrayList]@()
		$j = 0
		foreach ($element in $clusternodeCidr) { 
			if ($element -eq $clusternodeCidr[$ClusterResource[$i-1].PointerIndex]) {
				$null = $clusterowners.Add($clusternode[$j])
			}
			++$j
		}
		Get-ClusterResource -Name $ClusterResource[$i-1].ResourceName | Set-ClusterOwnerNode -Owners $clusterowners
		Write-Host("Cluster IP $($ClusterResource[$i-1].ResourceName) ownernode updated")
	}

	try {
		If (-not($nodes%2)) {
			Set-ClusterQuorum -NodeAndFileShareMajority "$fswlocation"
			Write-Host("Fsx File Witness setup successfully")
		}
	} 
	catch {
		Write-Host($_)
	}

	$sw.stop()
	$timer = ($sw.elapsed | select TotalMinutes).TotalMinutes
	Write-Host("Elapsed time for cluster is $timer minutes")

} else { Write-Host ("Cluster: $clustercheck Already exists.....exiting") }