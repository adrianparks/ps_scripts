# labesx11,12,13,14: vmnic2,vmnic3,vmnic4,vmnic5

# vmnic2,vmnic3: Mgt,vMotion,VM
# vmnic4,vmnic5: iSCSI

$DRHosts = @("labesx11.oucs.ox.ac.uk","labesx12.oucs.ox.ac.uk")
$ProdHosts = @("labesx13.oucs.ox.ac.uk","labesx14.oucs.ox.ac.uk")
$AllHosts = $DRHosts + $ProdHosts

$Prod_dvSwitches = "Prod_dvSwitch0","Prod_dvSwitch1"
$DR_dvSwitches = "DR_dvSwitch0","DR_dvSwitch1"

# Add hosts to dvSwitches

Foreach ($dvSwitch in $Prod_dvSwitches) {
    Get-VDSwitch -Name $dvSwitch | Add-VDSwitchVMHost -VMHost $ProdHosts
    Write-Host "Added production hosts to $dvSwitch"
}

Foreach ($dvSwitch in $DR_dvSwitches) {
    Get-VDSwitch -Name $dvSwitch | Add-VDSwitchVMHost -VMHost $DRHosts
    Write-Host "Added DR hosts to $dvSwitch"
}

Foreach ($VMHost in $ProdHosts) {

    # Add vmnic4 and vmnic5 to dvSwitch1
    $dvS = Get-VDSwitch -Name Prod_dvSwitch1    
    $vmnic4 = Get-VMHost -Name $VMHost | Get-VMHostNetworkAdapter -Physical -Name vmnic4
    $dvS | Add-VDSwitchPhysicalNetworkAdapter `
             -VMHostNetworkAdapter $vmnic4 -Confirm:$False
    $vmnic5 = Get-VMHost -Name $VMHost | Get-VMHostNetworkAdapter -Physical -Name vmnic5
    $dvS | Add-VDSwitchPhysicalNetworkAdapter `
             -VMHostNetworkAdapter $vmnic5 -Confirm:$False

    # Add vmnic3 to dvSwitch0

    $dvS = Get-VDSwitch -Name Prod_dvSwitch0
    $vmnic3 = Get-VMHost -Name $VMHost | Get-VMHostNetworkAdapter -Physical -Name vmnic3
    $dvS | Add-VDSwitchPhysicalNetworkAdapter `
             -VMHostNetworkAdapter $vmnic3 -Confirm:$False

    # Migrate vmk0

    $VSS_Mgmt_PG = "Management Network"
    Write-Host "Migrating $VSS_Mgmt_PG to Prod_dvSwitch0"
    $VDS_Mgmt_PG = Get-VDPortgroup -name "Prod_vSphere Management" -VDSwitch Prod_dvSwitch0
    $vmk = Get-VMHostNetworkAdapter -Name vmk0 -VMHost $VMHost
    Set-VMHostNetworkAdapter -PortGroup $VDS_Mgmt_PG -VirtualNic $vmk -Confirm:$False

    # Move vmnic2 over to dvSwitch0

    $dvS = Get-VDSwitch -Name Prod_dvSwitch0
    $vmnic2 = Get-VMHost -Name $VMHost | Get-VMHostNetworkAdapter -Physical -Name vmnic2
    $dvS | Add-VDSwitchPhysicalNetworkAdapter `
             -VMHostNetworkAdapter $vmnic2 -Confirm:$False

    # Remove vSwitch0 (the original VSS)
    Get-VirtualSwitch -VMHost $VMHost -Name vSwitch0 | Remove-VirtualSwitch -Confirm:$False

}

Foreach ($VMHost in $DRHosts) {

    # Add vmnic4 and vmnic5 to dvSwitch1
    $dvS = Get-VDSwitch -Name DR_dvSwitch1    
    $vmnic4 = Get-VMHost -Name $VMHost | Get-VMHostNetworkAdapter -Physical -Name vmnic4
    $dvS | Add-VDSwitchPhysicalNetworkAdapter `
             -VMHostNetworkAdapter $vmnic4 -Confirm:$False
    $vmnic5 = Get-VMHost -Name $VMHost | Get-VMHostNetworkAdapter -Physical -Name vmnic5
    $dvS | Add-VDSwitchPhysicalNetworkAdapter `
             -VMHostNetworkAdapter $vmnic5 -Confirm:$False

    # Add vmnic3 to dvSwitch0

    $dvS = Get-VDSwitch -Name DR_dvSwitch0
    $vmnic3 = Get-VMHost -Name $VMHost | Get-VMHostNetworkAdapter -Physical -Name vmnic3
    $dvS | Add-VDSwitchPhysicalNetworkAdapter `
             -VMHostNetworkAdapter $vmnic3 -Confirm:$False

    # Migrate vmk0

    $VSS_Mgmt_PG = "Management Network"
    Write-Host "Migrating $VSS_Mgmt_PG to DR_dvSwitch0"
    $VDS_Mgmt_PG = Get-VDPortgroup -name "DR_vSphere Management" -VDSwitch DR_dvSwitch0
    $vmk = Get-VMHostNetworkAdapter -Name vmk0 -VMHost $VMHost
    Set-VMHostNetworkAdapter -PortGroup $VDS_Mgmt_PG -VirtualNic $vmk -Confirm:$False

    # Move vmnic2 over to dvSwitch0

    $dvS = Get-VDSwitch -Name DR_dvSwitch0
    $vmnic2 = Get-VMHost -Name $VMHost | Get-VMHostNetworkAdapter -Physical -Name vmnic2
    $dvS | Add-VDSwitchPhysicalNetworkAdapter `
             -VMHostNetworkAdapter $vmnic2 -Confirm:$False

    # Remove vSwitch0 (the original VSS)
    Get-VirtualSwitch -VMHost $VMHost -Name vSwitch0 | Remove-VirtualSwitch -Confirm:$False

}
