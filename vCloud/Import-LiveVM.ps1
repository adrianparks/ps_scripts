# Import-LiveVM.ps1
# 
# Import a VM from a vSphere environment to a vCloud Director while VM is still running
# This functionality is not surfaced in the vCD web interface so must be done via an API call
#
# This script is almost entirely Jon Waite's work (http://kiwicloud.ninja/2016/08/live-import-vms-to-vcloud-director/)
# but with some minor edits to suit the OxCloud environment. Original is available from
# https://raw.githubusercontent.com/jondwaite/vcdliveimport/master/liveimport.ps1
#
#
#
#
#
#

# vCD API endpoint
$CIServer = ''

# vCenter server
# note this needs to be the short name not the FQDN
$VIServer = 'labvc04'

# credentials file must pre-exist
# If it doesn't, create it as follows:
# New-VICredentialStoreItem -Host <vc-fqdn> -File C:\Temp\vcreds.xml -user <user> -password <password>

$CredentialsFile = 'C:\Temp\vcreds.xml'

try { Test-Path -EA Stop $CredentialsFile | Out-Null;
   
   $CICreds = Get-VICredentialStoreItem -Host $CIServer -File $CredentialsFile
   $VICreds = Get-VICredentialStoreItem -Host $VIServer -File $CredentialsFile

} 
catch { 

   $ErrMessage = 
"Could not find credentials file $CredentialsFile for logon to vCloud Director and vCenter.
Make sure this exists - if not, create with:
   New-VICredentialStoreItem -Host $CIServer -File C:\Temp\vcreds.xml -user <user> -password <password>
   New-VICredentialStoreItem -Host $VIserver -File C:\Temp\vcreds.xml -user <user> -password <password>
Aborting script"

   Write-Host $ErrMessage
}

# If not already connected then connect to vCD
if (!$cloud.IsConnected) {
    try {
        $cloud = Connect-CIServer -Server $CIServer -Org 'system' -User $CICreds.User -Password $CICreds.Password -ErrorAction Stop
    }
    catch {
        # Write-Warning $_.Exception.Message
        Write-Host "Could not connect to vCloud Director endpoint (credentials correct?), exiting."
        $credentials = ""
        exit 1
    }
}
Write-Host "Connection to vCloud Director API endpoint $CIServer was successful"

# Find all of our Provider Virtual Datacenters (pVDCs) and add to a hash:
$pvdcs = @{}
$pvdcobjs = Get-ProviderVdc
Write-Host "vCenter(s) Found:"
Write-Host "-----------------"
foreach ($pvdc in $pvdcs) {
    $pvdcs.Add($pvdcobjs.ExtensionData.VimServer.Name, $pvdcobjs.ExtensionData.VimServer.Href)
    Write-Host "$($pvdcobjs.ExtensionData.VimServer.Name) ($($pvdcobjs.ExtensionData.VimServer.Href))"
}
Write-Host ""

$vimServer = ""
$vcenter = ""
while (! $vimServer) {
    if ($pvdcs.Count -eq 1) {
           write-Host "Selecting $($pvdcs.keys[0]) as only pVDC vCenter found."
           $vcenter = $pvdcs.keys[0]
           $vimServer = $pvdcs[$pvdcs.keys[0]]
    } else {
        $pvdcentry = Read-Host -Prompt 'vCenter containing the VM to be imported (or quit to exit)'
        if ($pvdcs.ContainsKey($pvdcentry)) {
            $vcenter = $pvdcentry
            $vimServer = $pvdcs[$pvdcentry]
        } else {
            if ($pvdcentry -eq 'quit') {
                Write-Host "Quit selected, exiting."
                Exit
            }
            Write-Host "vCenter $pvdcentry is not found, please type an entry from the list."
        }
    }
}
Write-Host "vCenter $vcenter selected." 

# If not already connected to this vCenter attempt connection:
if (!$vc.IsConnected) {
    try {
        $vc = Connect-VIServer -Server $vcenter -User $VICreds.User -Password $VICreds.Password -ErrorAction Stop
    }
    catch {
        Write-Warning $_.Exception.Message
        Write-Host "Could not connect to vCenter $vcenter (credentials correct?), exiting."
        $credentials = ""
        Exit
    }
}
Write-Host "Connected to vCenter Server $vcenter OK"
Write-Host ""

# Build hash of available VM names/MoRefs to be live imported:
$vms = @{}
$vmlist = Get-VM

Write-Host -NoNewLine "Evaluating vCenter VMs as migration candidates."
foreach ($vm in $vmlist) {
    $vmvalid = $true
    # If not powered on then we can import in GUI and no need for this script:
    if ($vm.PowerState -ne 'PoweredOn') { $vmvalid = $false }
    # Exclude Guest Introspection appliances from VM list:
    if ($vm.Name -like 'Guest Introspection*') { $vmvalid = $false }
    # Exclude Trend appliances from VM list:
    if ($vm.Name -like 'Trend Micro Deep Security*') { $vmvalid = $false }
    # Exclude NSX controllers from VM list:
    if ($vm.Name -like 'NSX_Controller_*') { $vmvalid = $false }
    # if CustomFields.Values exists and has a value we're already managed by vCD:
    if ($vm.CustomFields.Values -ne '') { $vmvalid = $false }
    # If we've passed validation then add candidate VM to array:
    if ($vmvalid) { 
        $moref = $vm.ExtensionData.MoRef.Value
        $vms.Add($vm.name, $moref)
    }
    Write-Host -NoNewline "."
}
Write-Host ""
Write-Host "Available candidate VMs:"
Write-Host "------------------------"

foreach ($vmname in $vms.Keys) {
    Write-Host $vmname
}

$vmmig = ""
Write-Host ""

while (! $vmmig) {
    $vmentry = Read-Host -Prompt "Enter VM name to live-migrate to vCloud (or 'quit' to exit)"
    if ($vmentry -eq 'quit') {
        write-Host "'quit' selected, exiting."
        Exit
    }
    if ($vms.Contains($vmentry)) {
        $vmmig = $vmentry
    } else {
        Write-Host "VM $vmentry is not found, please type an entry from the list."
    }
}
Write-Host "Selected VM $vmmig for live import to vCloud."
Write-Host ""

# Build hash of available VDC names/Hrefs as destination:
$vdcs = @{}
$vdclist = Get-OrgVdc
Write-Host "Available VDCs:"
Write-Host "---------------"
foreach ($vdc in $vdclist) {
    if ($vdc.Enabled) {
        Write-Host $vdc.Name
        $vdcs.Add($vdc.Name, $vdc.Href)
    }
}

$destvdc = ""
$desthref = ""
while (! $destvdc) {
    $vdcentry = Read-Host -Prompt 'Enter Destination VDC Name (or quit to exit)'
    if ($pvdcentry -eq 'quit') {
        Write-Host "Quit selected, exiting."
        Exit
    }
    if ($vdcs.ContainsKey($vdcentry)) {
        $destvdc = $vdcentry
        $desthref = $vdcs[$vdcentry]
    } else {
        Write-Host "VDC '$vdcentry' is not found, please type an entry from the list."
    }
    
}
Write-Host "VDC '$destvdc' selected." 

$nl = [Environment]::NewLine

$xml  = '<?xml version="1.0" encoding="UTF-8"?>' + $nl
$xml += '<ImportVmAsVAppParams xmlns="http://www.vmware.com/vcloud/extension/v1.5" name="' + $vmmig + '" sourceMove="true">' + $nl
$xml += '  <VmMoRef>' + $vms[$vmmig] + '</VmMoRef>' + $nl
$xml += '  <Vdc href="'+ $desthref +'" />' + $nl
$xml += '</ImportVmAsVAppParams>'

$uri = $vimServer[0] + '/importVmAsVApp'

Write-Host ""
Write-Host "URI for POST operation:"
Write-Host "$uri"
Write-Host ""
Write-Host "XML Document Body:"
Write-Host $xml
Write-Host ""
Write-Host "Content-Type: application/vnd.vmware.admin.importVmAsVAppParams+xml"
Write-Host ""

$confirm = ""

while (! $confirm) {
    $confirm = Read-Host -Prompt 'Would you like to submit this API request to live import this VM? (y or n) (or quit to exit)'
    if ($confirm -eq 'quit') {
        Write-Host "Quit selected, exiting."
        Exit
    }
    if ($confirm -eq 'n') {
        Exit
    }
    if ($confirm -eq 'y') {
        Write-Host "Making request to live import VM $vmmig..."

        $headers = @{"Accept"="application/*+xml;version=20.0"}
        $headers += @{"x-vcloud-authorization"=$cloud.SessionId}
        
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $xml -ContentType "application/vnd.vmware.admin.importVmAsVAppParams+xml"
        Write-Host "Response was:"
        Write-Host $response.InnerXml
    }
}
