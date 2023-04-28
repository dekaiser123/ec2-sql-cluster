$clustercheck = (get-cluster -ErrorAction SilentlyContinue).name
if (-not [string]::IsNullOrEmpty($clustercheck)) {

    Import-Module SqlServer

    $computer = hostname
    $AlwaysOn = (Invoke-Sqlcmd -query "SELECT SERVERPROPERTY ('IsHadrEnabled') as Enabled;" -ServerInstance $computer).Enabled
    If ($AlwaysOn -eq 0) {
        #Enable AlwaysOn Features 
        $Path_EnableAG="SQLSERVER:\Sql\"+$computer+"\DEFAULT"
        Enable-SqlAlwaysOn -Path $Path_EnableAG -Force

        #Restart SQL Server
        Restart-service -Name 'MSSQLSERVER' -Force
        Restart-service -Name 'SQLSERVERAgent' -Force

        Write-Host("AlwaysOn AG Enabled")
    }

} else {
    Write-Host("No Cluster exists - Create Windows Failover Cluster first")
}