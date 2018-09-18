
$DRHosts = "labesx11.oucs.ox.ac.uk","labesx12.oucs.ox.ac.uk"
$ProdHosts = "labesx13.oucs.ox.ac.uk","labesx14.oucs.ox.ac.uk"
$AllHosts = $DRHosts + $ProdHosts

$Prod_dvSwitches = "Prod_dvSwitch0","Prod_dvSwitch1"
$DR_dvSwitches = "DR_dvSwitch0","DR_dvSwitch1"


# Check hosts have the right naming convention

Foreach ($VMHost in $AllHosts) {
    $HostNum = $VMHost.Substring(6,2)
    Try {
        $TestNum = [int]$HostNum
        Write-Host "Checking host $VMHost"
    }
    Catch {
        Write-Host "ESXi hostname is not labesxNN.oucs.ox.ac.uk"
        Write-Host "Cannot gather host number - aborting script"
        Exit 1
    }
}

# Add VMkernel ports to the hosts

Foreach ($VMHost in $ProdHosts) {

    $HostNum = $VMHost.Substring(6,2)
	$IPNum = [int]$HostNum
    $vRPAiSCSIIP = "192.168.103." + $IPNum
    Write-Host "Adding VRPA iSCSI VMkernel port to $VMHost"
    New-VMHostNetworkAdapter -VMHost $VMHost -PortGroup "iSCSI Storage 1" `
       -VirtualSwitch Prod_dvSwitch1 -IP $vRPAiSCSIIP -SubnetMask 255.255.255.0

	Write-Host "Binding vmk port to iSCSI adapter"
	$HBA = Get-VMHost $VMHost | Get-VMHostHba -Type iScsi | `
            Where {$_.Model -eq "iSCSI Software Adapter"}

	$esxcli = Get-EsxCli -VMhost $VMHost

	$vmkAdapter = Get-VMHost $VMHost | Get-VMHostNetworkAdapter -Name vmk4 -VMKernel
	$esxcli.iscsi.networkportal.add($HBA.Device, $false, $vmkAdapter) | Out-Null
	   

}	
	
Foreach ($VMHost in $DRHosts) {

    $HostNum = $VMHost.Substring(6,2)
	$IPNum = [int]$HostNum
    $vRPAiSCSIIP = "192.168.103." + $IPNum
    Write-Host "Adding VRPA iSCSI VMkernel port to $VMHost"
    New-VMHostNetworkAdapter -VMHost $VMHost -PortGroup "DR_iSCSI Storage 1" `
       -VirtualSwitch DR_dvSwitch1 -IP $vRPAiSCSIIP -SubnetMask 255.255.255.0
	
	Write-Host "Binding vmk port to iSCSI adapter"
	$HBA = Get-VMHost $VMHost | Get-VMHostHba -Type iScsi | `
            Where {$_.Model -eq "iSCSI Software Adapter"}

	$esxcli = Get-EsxCli -VMhost $VMHost

	$vmkAdapter = Get-VMHost $VMHost | Get-VMHostNetworkAdapter -Name vmk4 -VMKernel
	$esxcli.iscsi.networkportal.add($HBA.Device, $false, $vmkAdapter) | Out-Null

}








