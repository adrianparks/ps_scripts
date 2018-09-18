$DRHosts = @("labesx11.oucs.ox.ac.uk","labesx12.oucs.ox.ac.uk")
$ProdHosts = @("labesx13.oucs.ox.ac.uk","labesx14.oucs.ox.ac.uk")

$DRCluster = "DR"
$ProdCluster = "PROD"

Foreach ($VMHost in $DRHosts) {
	Move-VMHost -VMHost $VMHost -Destination $DRCluster
}

Foreach ($VMHost in $ProdHosts) {
	Move-VMHost -VMHost $VMHost -Destination $ProdCluster
}