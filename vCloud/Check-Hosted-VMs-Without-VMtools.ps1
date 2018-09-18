##################################################################################################################
##### Script Information #########################################################################################
##################################################################################################################
#Name:			Check-Hosted-VMs-Without-VMtools
#Author:		Adrian Parks
#Created:		11 April 2013
#Purpose:		Checks for running VMs without VMware Tools installed in the Hosted VMs datacentre
#Revisions:		1.0	  Initial Version 
#				
# This script extracts all running VMs that do not have VMware Tools installed in the Hosted VMs vDC. 
# It then emails the VM's listed owner to moan about this.
#
# You will need to add the following VMware snapins if they are not already installed
# Add-PsSnapin VMware.VimAutomation.Core -ea "SilentlyContinue"
# Add-PsSnapin VMware.VimAutomation.Cloud -ea "SilentlyContinue"
#
# You will also need to have the OxCloud_Functions module installed
# See https://svn.oucs.ox.ac.uk/groups/nsms/src/n/nsms-vcloud-scripts/trunk/OxCloud_Functions for details
# Import the OxCloud_Functions module to provide Send-Email and Write-Log functions

Import-Module OxCloud_Functions

$MailFrom = ""
$LogPath = 'C:\Scripts\ScriptLogs\'

# credentials file must pre-exist
# If it doesn't, create it as follows:
# New-VICredentialStoreItem -Host <vcd-endpoint-fqdn> -File C:\Temp\vcreds.xml -user <user> -password <password>

$CredentialsFile = 'C:\Scripts\vcreds.xml'

$CIServer = "" # enter the API endpoint for the vCD cell here
$CIUser = "administrator"

$OrgvDC = "" # enter the Org vDC to check

$timer = [System.Diagnostics.Stopwatch]::StartNew()
$timer.reset()
$timer.start()

$LogFile = "Check-Hosted-VMs-Without-VMtools" + (Get-Date -uformat %d-%m-%y_%H-%M-%S) + ".log"
$LogFilePath = $LogPath + "\" + $LogFile
Write-Log -LogFile $LogFilePath -CreateLogFile

# Check that credentials file exists
if (!(Test-Path $CredentialsFile)) {
	Write-Log -LogFile $LogFilePath -Date -Level "ERROR" -Message "Could not find credentials file needed for access to vCloud Director cell"
	exit 1
} else {
	Write-Log -LogFile $LogFilePath -Date -Level "INFO" -Message "Found vCloud Director credentials file"
	$CICreds = Get-VICredentialStoreItem -Host $CIServer -File $CredentialsFile
}
				
# Test connection to the vCloud Director cell
Write-Log -LogFile $LogFilePath -Date -Level "INFO" -Message ("Checking connection to vCloud Director cell...")
if (Connect-CIServer -Server $CIServer -User $CICreds.User -Password $CICreds.Password -ErrorAction SilentlyContinue){
	Write-Log -LogFile $LogFilePath -Date -Level "INFO" -Message "Connection to vCloud Director cell successful"
}else{
	Write-Log -LogFile $LogFilePath -Date -Level "ERROR" -Message "Connection to vCloud Director cell failed - aborting script."
	$error >> $LogFilePath
	exit 1			
}

# Define the two Org Vdcs we want to search through
$OrgVdcs = @()
$OrgVdcs = Get-OrgVdc | Where {($_.Name -eq $OrgvDC)} | Foreach { $_.ID }

# Get a list of VMs without VMware Tools installed in the two Org Vdcs
$VMsWithNoTools = Search-Cloud -querytype AdminVm -Property Name,VmToolsVersion,ContainerName,Vdc | Where {($_.VmToolsVersion -eq "0") -And ($OrgVdcs -contains $_.Vdc)}

# Build a list of VMs without VMware Tools installed
$BrokenVMs = @()

Write-Log -LogFile $LogFilePath -Date -Level "INFO" -Message ("Building list of VMs without VMware Tools installed...")	

$VMsWithNoTools | %{

	$VMName = $_.Name
	$ContainerName = $_.ContainerName

	$vApp = Get-CIVapp | where {$_.Name -eq $ContainerName}
	if (!$vApp) {
		$vApp = Get-CIVAppTemplate | where {$_.Name -eq $ContainerName}
	}

	if (!$vApp) {
		Write-Log -LogFile $LogFilePath -Date -Level "WARN" -Message ("Couldn't find an associated vApp for VM '" + $VMName + "'")	
	} else {
	
		$BrokenVM = "" | Select Name, Owner, Email
		$BrokenVM.Name = $_.Name
		$BrokenVM.Owner = $vApp.Owner.Name
		$BrokenVM.Email = $vApp.Owner.Email
		
		$BrokenVMs += $BrokenVM
	}
	
}

Write-Log -LogFile $LogFilePath -Date -Level "INFO" -Message ($BrokenVMs | Format-Table -Property Name, Owner, Email | Out-String)	

$BrokenVMs | Foreach {

	$Email = $_.Email
	If (!$Email) {
		Write-Log -LogFile $LogFilePath -Date -Level "WARN" -Message ("Cannot send email to vApp owner '" + $_.Owner + "' about VM '" + $_.Name + "' as there is no email account associated with this username - please fix!")
	} Else {
		Write-Log -LogFile $LogFilePath -Date -Level "INFO" -Message ("Sending email to " + $Email + " (account '" + $_.Owner + "') moaning about VM '" + $_.Name + "'")

		$MailSubject = "VM '" + $_.Name + "' needs VMware Tools installed"
		$MailBody = "Dear VM Administrator,`r`n
<nagging email here>
Regards,
"

	Send-Email -MailTo $Email -MailFrom $MailFrom -MailSubject $MailSubject -MailBody $MailBody
#	Write-Log -LogFile $LogFilePath -Date -Level "INFO" -Message ("$Email`r`n$MailSubject`r`n$MailBody")
	}

}

$duration = ($timer.elapsed).totalseconds
Write-Host "Script run time $duration seconds"


# __END__

