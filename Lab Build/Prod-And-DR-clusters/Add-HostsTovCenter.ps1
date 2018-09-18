$DRHosts = @("labesx11.oucs.ox.ac.uk","labesx12.oucs.ox.ac.uk")
$ProdHosts = @("labesx13.oucs.ox.ac.uk","labesx14.oucs.ox.ac.uk")

New-Datacenter -Location Datacenters -Name Lab-VIDAR

Foreach ($VMHost in $DRHosts) {
	Add-VMHost -Name $VMHost -Location (Get-Datacenter) -RunAsync -Force
}

Foreach ($VMHost in $ProdHosts) {
	Add-VMHost -Name $VMHost -Location (Get-Datacenter) -RunAsync -Force
}

