$DRCluster = "DR"
$ProdCluster = "PROD"

$Prod_dvSwitch0 = "Prod_dvSwitch0"

$Prod_dvSwitches = "Prod_dvSwitch0","Prod_dvSwitch1"
$DR_dvSwitches = "DR_dvSwitch0","DR_dvSwitch1"
$All_dvSwitches = $Prod_dvSwitches + $DR_dvSwitches

$Prod_Portgroups_VDS0 = @{"Prod_vSphere Management" = "100"; "Prod_vMotion" = "102"; "Prod_VM Network" = "200"}
$Prod_Portgroups_VDS1 = @{"Prod_iSCSI Storage 1" = "101"; "Prod_iSCSI Storage 2" = "101"}

$DR_Portgroups_VDS0 = @{"DR_vSphere Management" = "100"; "DR_vMotion" = "102"; "DR_VM Network" = "200"}
$DR_Portgroups_VDS1 = @{"DR_iSCSI Storage 1" = "101"; "DR_iSCSI Storage 2" = "101"}

# Create the clusters

New-Cluster -Name $ProdCluster -Location (Get-Datacenter)
New-Cluster -Name $DRCluster -Location (Get-Datacenter)

# Create the dvSwitches

Foreach ($dvSwitch in $All_dvSwitches) {
   New-VDSwitch -Name $dvSwitch -NumUplinkPorts 2 -Version 6.5.0 `
   -Location (Get-Datacenter) -RunAsync
}


# Add portgroups to Prod_dvSwitch0 and set LBT load balancing policy
Foreach ($Portgroup in $Prod_Portgroups_VDS0.keys) {
    Get-VDSwitch -Name $Prod_dvSwitches[0] | New-VDPortGroup -Name $Portgroup `
	   -NumPorts 8 -PortBinding Static -VlanID $Prod_Portgroups_VDS0[$Portgroup]
    Get-VDPortGroup -Name $Portgroup | Get-VDUplinkTeamingPolicy | `
	   Set-VDUplinkTeamingPolicy -LoadBalancingPolicy LoadBalanceLoadBased
}

# Add portgroups to Prod_dvSwitch1
Foreach ($Portgroup in $Prod_Portgroups_VDS1.keys) {
    Get-VDSwitch -Name $Prod_dvSwitches[1] | New-VDPortGroup -Name $Portgroup `
	   -NumPorts 8 -PortBinding Static -VlanID $Prod_Portgroups_VDS1[$Portgroup]
}

# Set NIC teaming policy to active/standby on Prod_dvSwitch1 iSCSI portgroups

# Get Prod_dvSwitch1 portgroups into a list, this is ugly
$iSCSI_Portgroups = $Prod_Portgroups_VDS1.keys[0].Split("\n")
Get-VDPortGroup -Name $iSCSI_Portgroups[0] | Get-VDUplinkTeamingPolicy | `
   Set-VDUplinkTeamingPolicy -ActiveUplinkPort dvUplink1 -UnusedUplinkPort dvUplink2
Get-VDPortGroup -Name $iSCSI_Portgroups[1] | Get-VDUplinkTeamingPolicy | `
   Set-VDUplinkTeamingPolicy -ActiveUplinkPort dvUplink2 -UnusedUplinkPort dvUplink1

# Add portgroups to DR_dvSwitch0 and set LBT load balancing policy
Foreach ($Portgroup in $DR_Portgroups_VDS0.keys) {
    Get-VDSwitch -Name $DR_dvSwitches[0] | New-VDPortGroup -Name $Portgroup `
	   -NumPorts 8 -PortBinding Static -VlanID $DR_Portgroups_VDS0[$Portgroup]
    Get-VDPortGroup -Name $Portgroup | Get-VDUplinkTeamingPolicy | `
	   Set-VDUplinkTeamingPolicy -LoadBalancingPolicy LoadBalanceLoadBased
}

# Add portgroups to DR_dvSwitch1
Foreach ($Portgroup in $DR_Portgroups_VDS1.keys) {
    Get-VDSwitch -Name $DR_dvSwitches[1] | New-VDPortGroup -Name $Portgroup `
	   -NumPorts 8 -PortBinding Static -VlanID $DR_Portgroups_VDS1[$Portgroup]
}

# Set NIC teaming policy to active/standby on DR_dvSwitch1 iSCSI portgroups

# Get DR_dvSwitch1 portgroups into a list, this is still ugly
$iSCSI_Portgroups = $DR_Portgroups_VDS1.keys[0].Split("\n")
Get-VDPortGroup -Name $iSCSI_Portgroups[0] | Get-VDUplinkTeamingPolicy | `
   Set-VDUplinkTeamingPolicy -ActiveUplinkPort dvUplink1 -UnusedUplinkPort dvUplink2
Get-VDPortGroup -Name $iSCSI_Portgroups[1] | Get-VDUplinkTeamingPolicy | `
   Set-VDUplinkTeamingPolicy -ActiveUplinkPort dvUplink2 -UnusedUplinkPort dvUplink1


