$ProdHosts = @("labesx11.oucs.ox.ac.uk","labesx12.oucs.ox.ac.uk","labesx13.oucs.ox.ac.uk","labesx14.oucs.ox.ac.uk")

$ProdCluster = "PROD"

Foreach ($VMHost in $ProdHosts) {
	Move-VMHost -VMHost $VMHost -Destination $ProdCluster
}