$ProdHosts = @("labesx11.oucs.ox.ac.uk","labesx12.oucs.ox.ac.uk","labesx13.oucs.ox.ac.uk","labesx14.oucs.ox.ac.uk")

$DC_Name = "Lab-VIDAR"

New-Datacenter -Location Datacenters -Name $DC_Name

Foreach ($VMHost in $ProdHosts) {
	Add-VMHost -Name $VMHost -Location (Get-Datacenter) -RunAsync -Force
}

