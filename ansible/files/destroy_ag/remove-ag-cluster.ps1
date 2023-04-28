$Global:ProgressPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

$DomainName = (Get-SSMParameterValue -Name "/Shared/AD/MicrosoftAD/RootDomain").Parameters.value
$domainjoinedcheck = (Get-ComputerInfo -Property "*domain*").CsDomain
if ($domainjoinedcheck.ToLower() -eq $DomainName.ToLower()) {

    $Aws_Avail_Zone = (curl -UseBasicParsing http://169.254.169.254/latest/meta-data/placement/availability-zone).Content
    $Aws_Region = $Aws_Avail_Zone.Substring(0, $Aws_Avail_Zone.length - 1)
    $Aws_Instance_Id = (curl -UseBasicParsing http://169.254.169.254/latest/meta-data/instance-id).Content
    $InstanceID = (curl http://169.254.169.254/latest/meta-data/instance-id -UseBasicParsing).content
    $InstanceName = aws ec2 describe-tags --filters Name=resource-id,Values=$instanceID Name=key,Values=Name --query Tags[].Value --output text

    $DomainJoinUsername = (Get-SSMParameterValue -Name "/Shared/AD/DomainJoin/ServiceAccount").Parameters.value
    $DomainJoinPassword = (Get-SSMParameterValue -Name "/Shared/AD/DomainJoin/Password" -WithDecryption $true).Parameters.value | ConvertTo-SecureString -AsPlainText -Force
    $JoinADAccountwithDomain = ($DomainName -split "\.")[0] + "\" + $DomainJoinUsername
    $credential = New-Object System.Management.Automation.PSCredential($JoinADAccountwithDomain, $DomainJoinPassword) -ErrorAction Stop


    #Check to ensure that the Failoverclusters module is installed
    $modulecheck = (Get-Module -ListAvailable | Where-Object { $_.Name -eq "FailoverClusters" }).count
    #Check that the Cluster service is running
    $servicecheck = (get-service -Name ClusSvc).Status
    #Check that this is the primary cluster node
    $clusterprimarycheck = (get-clusternode -name $env:computername | get-clusterresource).count
    #Check for the sql powershell module
    $sqlmodulecheck = (get-module -ListAvailable | Where-Object { $_.Name -eq "SqlServer" }).count

    if ( ($modulecheck -ge 1) -and ($servicecheck -eq "Running") -and ($clusterprimarycheck -gt 1) -and ($sqlmodulecheck -ge 1) ) {
        Write-Host "This is the primary"
        Import-Module SqlServer

        #this needs to run as the ad user in order to work - Configured in the ansible task.
        $ag = Get-ChildItem "SQLSERVER:\Sql\$env:computername\default\AvailabilityGroups"
        $agcheck = $ag.count

        if ($agcheck -ge 1) {
            Write-Host "Removing the SQL Availability Group"

            $agname = $ag.name
            $ag | Remove-SqlAvailabilityGroup

            Write-Host "Removing the Availability Group Computer Object"
            #Removing the AD computer object
            Add-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
            #Recently when this was run, the DNS entries were removed for the AG, but the AD Object still existed.
            Remove-ADComputer -Credential $credential -Identity $agname -Confirm:$false
        }

        Write-Host "Destroying the cluster"
        #Hashing as this script is running as the delegated domain admin account.
        $clustername = (get-cluster).name
        Get-Cluster -Name $clustername | Remove-Cluster -Force -CleanupAD
    }


    if ( ($modulecheck -ge 1) -and ($servicecheck -eq "Running") -and ($clusterprimarycheck -gt 1) ) {
      #Remove the ClusterListener if it exists
      $AgLisName = aws ec2 describe-tags --filters Name=resource-id,Values=$instanceID Name=key,Values=AgLis01 --query Tags[].Value --output text
      $clustergroup = Get-ClusterGroup -Name "$AgLisName" -ErrorAction SilentlyContinue
      $clustergroupcheck = $clustergroup.count

      if ($clustergroupcheck -ge 1) {
        Write-Host "Removing the Cluster Listener Group"

        Remove-ClusterGroup -Name "$AgLisName" -RemoveResources -Force

        Write-Host "Removing the Cluster Listener Computer Object"
          #Removing the AD computer object
          Add-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
          #Recently when this was run, the DNS entries were removed for the AG, but the AD Object still existed.
          Remove-ADComputer -Credential $credential -Identity $AgLisName -Confirm:$false
      }

      Write-Host "Destroying the cluster"
      #Hashing as this script is running as the delegated domain admin account.
      $clustername = (get-cluster).name
      Get-Cluster -Name $clustername | Remove-Cluster -Force -CleanupAD

    }

    Write-Host "Removing Computer Object from AD"

    #Removing the AD computer object
    Add-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
    Remove-ADComputer -Credential $credential -Identity $env:computername -Confirm:$false
    Write-Host "Script Run has completed."
    Restart-computer

}
else
{ Write-Host "Instance is not on the domain" }
