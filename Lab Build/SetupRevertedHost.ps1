# Reconnect a reverted host back to the dvSwitches
# 
# Only use this script when you have already used RevertHost.ps1, for a new 
# host use the standard build scripts. This one and RevertHost.ps1 are for
# quick config cleans without needing to rebuild the hypervisor from scratch
#
# look at the William Lam script to see about the parameters
# vmhost must be one

$VMHostName = "labesx11.oucs.ox.ac.uk"
$VMHost = Get-VMhost -Name $VMHostName

$Prod_dvSwitches = "Prod_dvSwitch0","Prod_dvSwitch1"

$Prod_dvSwitch0 = $Prod_dvSwitches[0]
$Prod_dvSwitch1 = $Prod_dvSwitches[1]

# Add hosts to dvSwitches

Foreach ($dvSwitch in $Prod_dvSwitches) {
    Get-VDSwitch -Name $dvSwitch | Add-VDSwitchVMHost -VMHost $VMHost
    Write-Host "Added host $VMHostName to $dvSwitch"
}

$dvS = Get-VDSwitch -Name Prod_dvSwitch1    

# Add vmnic4 and vmk2 to dvSwitch1
$vmnic4 = Get-VMHostNetworkAdapter -VMHost $VMHost -Physical -Name vmnic4
$VDS_iSCSI1_PG = Get-VDPortgroup -name "Prod_iSCSI Storage 1" -VDSwitch Prod_dvSwitch1
$vmk2 = Get-VMHostNetworkAdapter -Name vmk2 -VMHost $VMHost

$dvS | Add-VDSwitchPhysicalNetworkAdapter -VMHostVirtualNic $vmk2 `
   -VMHostPhysicalNic $vmnic4 -VirtualNicPortgroup $VDS_iSCSI1_PG -Confirm:$False

# Add vmnic5 and vmk3 to dvSwitch1
$vmnic5 = Get-VMHostNetworkAdapter -VMHost $VMHost -Physical -Name vmnic5
$VDS_iSCSI2_PG = Get-VDPortgroup -name "Prod_iSCSI Storage 2" -VDSwitch Prod_dvSwitch1
$vmk3 = Get-VMHostNetworkAdapter -Name vmk3 -VMHost $VMHost

$dvS | Add-VDSwitchPhysicalNetworkAdapter -VMHostVirtualNic $vmk3 `
   -VMHostPhysicalNic $vmnic5 -VirtualNicPortgroup $VDS_iSCSI2_PG -Confirm:$False

$dvS = Get-VDSwitch -Name Prod_dvSwitch0

# Add vmnic3 and vmk1 to dvSwitch0
$vmnic3 = Get-VMHostNetworkAdapter -VMHost $VMHost -Physical -Name vmnic3
$VDS_vMotion_PG = Get-VDPortgroup -name "Prod_vMotion" -VDSwitch Prod_dvSwitch0
$vmk1 = Get-VMHostNetworkAdapter -Name vmk1 -VMHost $VMHost

$dvS | Add-VDSwitchPhysicalNetworkAdapter -VMHostVirtualNic $vmk1 `
   -VMHostPhysicalNic $vmnic3 -VirtualNicPortgroup $VDS_vMotion_PG -Confirm:$False

# Add vmnic2 and vmk0 to dvSwitch0
$vmnic2 = Get-VMHostNetworkAdapter -VMHost $VMHost -Physical -Name vmnic2
$VDS_Mgmt_PG = Get-VDPortgroup -name "Prod_vSphere Management" -VDSwitch Prod_dvSwitch0
$vmk0 = Get-VMHostNetworkAdapter -Name vmk0 -VMHost $VMHost

$dvS | Add-VDSwitchPhysicalNetworkAdapter -VMHostVirtualNic $vmk0 `
   -VMHostPhysicalNic $vmnic2 -VirtualNicPortgroup $VDS_Mgmt_PG -Confirm:$False
  

# delete vSwitch0 and vSwitch1
Get-VirtualSwitch -VMHost $VMHost -Name vSwitch1 | Remove-VirtualSwitch -Confirm:$False
Get-VirtualSwitch -VMHost $VMHost -Name vSwitch0 | Remove-VirtualSwitch -Confirm:$False