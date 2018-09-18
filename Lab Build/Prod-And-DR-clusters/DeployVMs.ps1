# Deploy a bunch of VMs from template, with guest os customisation on

$TargetCluster = Get-Cluster -Name "PROD"
$SourceVMTemplate = Get-Template -Name "Win2012r2-Std-Template"

Try {
    $SourceCustomSpec = Get-OSCustomizationSpec -Name "Windows2012-DHCP-CustomSpec"
}
Catch {
	Write-Host "Creating OS Customisation specification"
#	New-OSCustomizationSpec –Name "Windows2012-DHCP-CustomSpec" -OSType Windows `
#		-Workgroup "ITS" -FullName "Administrator" -OrgName "ITS" -ChangeSid `
#		-AdminPassword 'win-pw-here' -NamingScheme Vm -TimeZone "085" `
#		-AutoLogonCount 2
}

$AllVMs = @()

$Datastore = "Resource_03"

$NumberOfVMsToDeploy = 1

# VM settings

$VMPrefix = "db"
$VMStartNo = 01
$VMSuffix = ".its.local"

$IPNetwork = "192.168.25."
$IPNum = 115
$Netmask = "255.255.255.0"
$IPGateway = "192.168.25.254"
$DNSServer = "163.1.2.1"


For ($VMCount=$VMStartNo; $VMCount -lt $NumberOfVMsToDeploy+$VMStartNo; $VMCount++) {

	If ($VMCount -lt 10) {
		$VMCountPrefix = "0"
	} Else {
		$VMCountPrefix = ""
	}

	$VMName = $VMPrefix + $VMCountPrefix + $VMCount + $VMSuffix
	$AllVMs += $VMName

	($VMShortName,$Rest) = ($VMName -split "\.").ToUpper()
	
	$IPAddress = $IPNetwork + $IPNum
	
	$IPNum++
	
	# change template from DHCP to static IP, do this for each VM
	$SourceCustomSpec | Get-OSCustomizationNicMapping | ` 
	Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $IPAddress `
			-SubnetMask $Netmask -DefaultGateway $IPGateway -Dns $DNSServer `
			| Out-Null

	# Sets the name of the VMs OS
	Set-OSCustomizationSpec -OSCustomizationSpec $SourceCustomSpec -NamingScheme Fixed `
							-NamingPrefix $VMShortName | Out-Null


	# Deploy new VM 
	New-VM -Name $VMName -Template $SourceVMTemplate `
				 -ResourcePool $TargetCluster `
				 -OSCustomizationSpec $SourceCustomSpec `
				 -Datastore $Datastore `
				 -Confirm:$false -RunAsync | Out-Null
				 
	Write-Host "Deploying VM $VMName..."

}

$CompletedCount = 0
While ($True) {
		
	$VIEvents = Get-VIEvent -Entity $AllVMs -ErrorAction SilentlyContinue
	$VIEvent = $VIEvents | Where { $_.FullFormattedMessage -match "Template $SourceVMTemplate deployed on host" }
	 
		If ($VIEvent) {
			Write-Host " "
			$LatestEvent = $VIEvent | Select-Object -First 1
			Write-Host $LatestEvent.FullFormattedMessage -NoNewLine
		    $CompletedCount++
			If ($CompletedCount -eq $NumberOfVMsToDeploy) { Break }
		}
	 
		Else {
			Start-Sleep -Seconds 1
			Write-Host "." -NoNewline
		}
}

Write-Host " "
Write-Host "All deployed"
	
Foreach ($VM in $AllVMs) {
	
	# Power on VM
	Write-Host "Powering on VM $VM"

	Get-VM -Name $VM | Get-NetworkAdapter | ` 
		   Set-NetworkAdapter -StartConnected $True -Confirm:$false | Out-Null
	Start-VM -VM $VM | Out-Null

}

Write-Host "Waiting for guest customization of VMs to start"
$CompletedCount = 0
While ($True) {
	
	$VIEvents = Get-VIEvent -Entity $AllVMs -ErrorAction SilentlyContinue
	$VIEvent = $VIEvents | Where { $_.GetType().Name -eq "CustomizationStartedEvent" }
 
		If ($VIEvent) {
			$CompletedCount++
			If ($CompletedCount -eq $NumberOfVMsToDeploy) {
				Write-Host " "
				Write-Host "Guest customization of all $NumberOfVMsToDeploy VMs is underway..."
				Break
			}
		}
 
		Else {
			Write-Host "." -NoNewline
			Start-Sleep -Seconds 5
		}
}

While ($True) {
	
	$VIEvents = Get-VIEvent -Entity $AllVMs -ErrorAction SilentlyContinue
	$CompletionEvents = $VIEvents | Where { $_.GetType().Name -eq "CustomizationSucceeded" `
									-Or $_.GetType().Name -eq "CustomizationFailed" }
		
	
	If ($CompletionEvents.Count -eq $NumberOfVMsToDeploy) {
	
			Write-Host " "
			Foreach ($CompletionEvent in $CompletionEvents) {
				Write-Host $CompletionEvent.FullFormattedMessage
			}
			Break
	} Else {
			Write-Host "." -NoNewline
			Start-Sleep -Seconds 1
	}
	
}

Write-Host "Done"

# __END__
