# Revert a host back to its default installation stance
# slight change is that it retains its storage, but on
# a local vSwitch. Saves a lot of Compellent reconfig later
# 

# vmnic2,vmnic3: Mgt,vMotion,VM
# vmnic4,vmnic5: iSCSI

# look at the William Lam script to see about the parameters
# vmhost must be one

$VMHostName = "labesx12.oucs.ox.ac.uk"

$VMHost = Get-VMhost -Name $VMHostName

# Create vSwitch1 for iSCSI
Write-Host "Creating vSwitch1"
$vSwitch1 = New-VirtualSwitch -VMHost $VMHost -Name vSwitch1

# Create portgroups on vSwitch1
$VSS_iSCSI1_PG = New-VirtualPortgroup -VirtualSwitch $vSwitch1 -VlanId 101 -Name "iSCSI Storage 1"
$VSS_iSCSI2_PG = New-VirtualPortgroup -VirtualSwitch $vSwitch1 -VlanId 101 -Name "iSCSI Storage 2"

# Migrate iSCSI vmks

$VDS_iSCSI2_PG_Name = "DR_iSCSI_Storage_2"

Write-Host "Migrating vmk3 to vSwitch1"
$vmk3 = Get-VMHostNetworkAdapter -Name vmk3 -VMHost $VMHost
$vmnic5 = Get-VMHostNetworkAdapter -VMHost $VMHost -Physical -Name vmnic5
Remove-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmnic5 -Confirm:$False
Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vSwitch1 -VMHostPhysicalNic $vmnic5 `
   -VMHostVirtualNic $vmk3 -VirtualNicPortgroup $VSS_iSCSI2_PG  -Confirm:$false

Write-Host "Migrating vmk2 to vSwitch1"
$vmk2 = Get-VMHostNetworkAdapter -Name vmk2 -VMHost $VMHost
$vmnic4 = Get-VMHostNetworkAdapter -VMHost $VMHost -Physical -Name vmnic4
Remove-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmnic4 -Confirm:$False
Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vSwitch1 -VMHostPhysicalNic $vmnic4 `
   -VMHostVirtualNic $vmk2 -VirtualNicPortgroup $VSS_iSCSI1_PG  -Confirm:$false

# Set NIC teaming policy on iSCSI portgroups

Get-VirtualPortGroup -VirtualSwitch $vSwitch1 -Name "iSCSI Storage 1" | Get-NicTeamingPolicy | `
   Set-NicTeamingPolicy -MakeNicActive $vmnic4 -MakeNicUnused $vmnic5
Get-VirtualPortGroup -VirtualSwitch $vSwitch1 -Name "iSCSI Storage 2" | Get-NicTeamingPolicy | `
   Set-NicTeamingPolicy -MakeNicActive $vmnic5 -MakeNicUnused $vmnic4

# Create vSwitch0 for vSphere Management and add vmnic2
Write-Host "Creating vSwitch0"
$vSwitch0 = New-VirtualSwitch -VMHost $VMHost -Name vSwitch0

# Create portgroups on vSwitch0
$VSS_Mgmt_PG = New-VirtualPortgroup -VirtualSwitch $vSwitch0 -VlanId 100 -Name "vSphere Management"
$VSS_vMotion_PG = New-VirtualPortgroup -VirtualSwitch $vSwitch0 -VlanId 102 -Name "vMotion"

# Migrate vmk0 (DR_vSphere Management) to vSwitch0

Write-Host "Migrating vmk0 to vSwitch0"
$vmk0 = Get-VMHostNetworkAdapter -Name vmk0 -VMHost $VMHost
$vmnic2 = Get-VMHostNetworkAdapter -VMHost $VMHost -Physical -Name vmnic2
Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vSwitch0 -VMHostPhysicalNic $vmnic2 `
   -VMHostVirtualNic $vmk0 -VirtualNicPortgroup $VSS_Mgmt_PG  -Confirm:$false

Write-Host "Migrating vmk1 to vSwitch0"
$vmk1 = Get-VMHostNetworkAdapter -Name vmk1 -VMHost $VMHost
$vmnic3 = Get-VMHostNetworkAdapter -VMHost $VMHost -Physical -Name vmnic3
Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vSwitch0 -VMHostPhysicalNic $vmnic3 `
   -VMHostVirtualNic $vmk1 -VirtualNicPortgroup $VSS_vMotion_PG  -Confirm:$false
  
# check they're both active and the NIC teaming policy is Source Port
# just have a look in the vSphere client for this as it should be OK

# Remove host from the dvSwitches

Get-VDSwitch -Name DR_dvSwitch0 | Remove-VDSwitchVMHost -VMHost $VMHost -Confirm:$false
Get-VDSwitch -Name DR_dvSwitch1 | Remove-VDSwitchVMHost -VMHost $VMHost -Confirm:$false

# At this point everything is on VSS
# Not quite the same as a new ESXi install as we have the storage and vMotion vmks in place
# but near enough














