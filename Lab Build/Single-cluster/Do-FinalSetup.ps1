
$DRHosts = @("labesx11.oucs.ox.ac.uk","labesx12.oucs.ox.ac.uk")
$ProdHosts = @("labesx13.oucs.ox.ac.uk","labesx14.oucs.ox.ac.uk")
$AllHosts = $DRHosts + $ProdHosts


Foreach ($VMHost in $AllHosts) {

	# Set system logs to go to Resource_02 datastore
	 
	$HostShortName = $VMHost.Substring(0,8)
	Get-AdvancedSetting -Entity (Get-VMHost $VMHost) -Name Syslog.global.logDir `
	| Set-AdvancedSetting -Value "[Resource_02] /log/$HostShortName" -Confirm:$False
	 	 
}