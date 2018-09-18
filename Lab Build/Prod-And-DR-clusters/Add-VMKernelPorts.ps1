
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
	$IPNum = [int]$HostNum + 40
    $iSCSI1IP = "192.168.100." + $IPNum
    $iSCSI2IP = "192.168.101." + $IPNum
    $vMotionIP = "192.168.102." + $IPNum
    Write-Host "Adding VMkernel ports to $VMHost"
    New-VMHostNetworkAdapter -VMHost $VMHost -PortGroup Prod_vMotion `
       -VirtualSwitch Prod_dvSwitch0 -IP $vMotionIP -SubnetMask 255.255.255.0 `
       -VMotionEnabled $True
    New-VMHostNetworkAdapter -VMHost $VMHost -PortGroup "Prod_iSCSI Storage 1" `
       -VirtualSwitch Prod_dvSwitch1 -IP $iSCSI1IP -SubnetMask 255.255.255.0
    New-VMHostNetworkAdapter -VMHost $VMHost -PortGroup "Prod_iSCSI Storage 2" `
       -VirtualSwitch Prod_dvSwitch1 -IP $iSCSI2IP -SubnetMask 255.255.255.0
}

Foreach ($VMHost in $DRHosts) {

    $HostNum = $VMHost.Substring(6,2)
	$IPNum = [int]$HostNum + 40
    $iSCSI1IP = "192.168.100." + $IPNum
    $iSCSI2IP = "192.168.101." + $IPNum
    $vMotionIP = "192.168.102." + $IPNum
	Write-Host "Adding VMkernel ports to $VMHost"
    Write-Host $vMotionIP
    New-VMHostNetworkAdapter -VMHost $VMHost -PortGroup DR_vMotion `
        -VirtualSwitch DR_dvSwitch0 -IP $vMotionIP -SubnetMask 255.255.255.0 `
        -VMotionEnabled $True
    New-VMHostNetworkAdapter -VMHost $VMHost -PortGroup "DR_iSCSI Storage 1" `
       -VirtualSwitch DR_dvSwitch1 -IP $iSCSI1IP -SubnetMask 255.255.255.0
    New-VMHostNetworkAdapter -VMHost $VMHost -PortGroup "DR_iSCSI Storage 2" `
       -VirtualSwitch DR_dvSwitch1 -IP $iSCSI2IP -SubnetMask 255.255.255.0
}







