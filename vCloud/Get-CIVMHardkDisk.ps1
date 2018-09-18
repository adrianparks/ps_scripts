Function Get-CIVMHardDisk {
Param (
[Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
$CIVM
)
Process {
$AllHDD = $CIVM.ExtensionData.getvirtualhardwaresection().Item | Where { $_.Description -like “Hard Disk”}
$HDInfo = @()
Foreach ($HD in $AllHDD) {
$HD | Add-Member -MemberType NoteProperty -Name “Capacity” -Value $HD.HostResource[0].AnyAttr[0].”#text”
$HD | Add-Member -MemberType NoteProperty -Name “VMName” -Value $CIVM.Name
$HDInfo += $HD
}
$HDInf
o
}

}