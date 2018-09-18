$DRHosts = @("labesx11.oucs.ox.ac.uk","labesx12.oucs.ox.ac.uk")
$ProdHosts = @("labesx13.oucs.ox.ac.uk","labesx14.oucs.ox.ac.uk")
$AllHosts = $DRHosts + $ProdHosts

$iSCSITargets = @("192.168.100.13","192.168.101.13")

Foreach ($VMHost in $AllHosts) {

    Write-Host "Adding iSCSI adapter to host $VMHost"
    Get-VMHostStorage -VMHost $VMHost | Set-VMHostStorage -SoftwareIScsiEnabled $True
    
    $HBA = Get-VMHost $VMHost | Get-VMHostHba -Type iScsi | `
            Where {$_.Model -eq "iSCSI Software Adapter"}

    Write-Host "Adding Compellent targets"
    Foreach ($Target in $iSCSITargets) {
        New-IScsiHbaTarget -IScsiHba $HBA -Address $Target 
    }  

    Write-Host "Rescanning iSCSI adapter"
    Get-VMHost $VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs | Out-Null

    Write-Host "Binding vmk ports to iSCSI adapter"
    $esxcli = Get-EsxCli -VMhost $VMHost

    Foreach ($vmk in ("vmk2","vmk3")) {
        $vmkAdapter = Get-VMHost $VMHost | Get-VMHostNetworkAdapter -Name $vmk -VMKernel
        $esxcli.iscsi.networkportal.add($HBA.Device, $false, $vmkAdapter) | Out-Null
     }
 
}

# Note that the datastores won't be seen yet, the Compellent needs to be set up
# with the iSCSI initiators (i.e. the IQNs of the servers)
# Either manually create the servers in Dell EM or use more PowerShell to
# do it. Then rescan the host adapters:

Foreach ($VMHost in $AllHosts) {

    Write-Host "Rescanning iSCSI adapter"
    Get-VMHost $VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs | Out-Null

}

